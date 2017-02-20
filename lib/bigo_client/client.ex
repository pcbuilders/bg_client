defmodule BigoClient.Client do

  def loop do
    Process.sleep 3600000
    loop
  end

  def main do
    :net_kernel.start([:"client@#{hname}", :longnames])
    System.get_env("BG_COOKIE")
    |> String.to_atom
    |> Node.set_cookie
    start
  end

  defp start do
    case call(:join, [hname]) do
      {:error, _} ->
        sleep
        start
      _ ->
        Task.start_link(fn -> get_conf end)
        work
    end
  end

  defp get_conf do
    File.write("conf.json", call(:conf))
    sleep 3600000
    get_conf
  end

  defp work do
    call(:get_tasks, [hname])
    |> Enum.chunk(5, 5, [])
    |> Enum.map(fn(x) -> process(x) end)
    sleep 30000
    work
  end

  defp process(tasks) do
    tasks
    |> Enum.map(fn(x) -> Task.async(fn -> request(x) end) end)
    |> Enum.map(fn(x) -> Task.await(x, 120000) end)
    |> Enum.map(fn(x) -> parse_status(x) end)
  end

  defp request({id, bigo_sid}) do
    case req(bigo_sid) do
      {:error, e} ->
        log "#{inspect {id, bigo_sid}} -> failed to get url -> #{inspect e}"
        nil
      {:ok, code, _, ref} ->
        status = stream_or_err(id, code, ref)
        :hackney.close ref
        status
    end
  end

  defp stream_or_err(id, code, ref) do
    case code do
      200 ->
        url               = :hackney.location(ref)
        {prot, host_port} = parse_url url
        if host_port === "bgprx.abylina.com" do
          log "#{id} -> live ended -> #{inspect host_port}"
          {id, 9}
        else
          body = to_body(ref)
          case capture_stream_url(body) do
            nil ->
              log "#{id} -> stream_url not found -> #{inspect body}"
              nil
            {sid, vid} ->
              Task.start(fn -> stream(id, url, "hls://#{to_string prot}://#{host_port}/list_#{sid}_#{vid}.m3u8") end)
              {id, 1}
          end
        end
      _ -> nil
    end
  end

  defp stream(id, ref_url, stream_url) do
    outpath = to_string(id) <> ".mp4"
    cmd = ["-Q", "--yes-run-as-root", "-o", outpath, "--hls-timeout", "300", "--hls-segment-timeout", "60", "--http-header", "'Referer=#{ref_url}'", stream_url, "best"]
    System.cmd("livestreamer", cmd)
    if File.exists?(outpath) do
      call(:update_status, [{id, 2, ""}])
      upload({id, outpath})
    else
      log "#{id} -> stream not found"
      call(:update_status, [{id, nil, ""}])
    end
  end

  defp upload(x) do
    {id, outpath} = x
    l             = inspect({id, "upload"})
    {res, _} = System.cmd("node", ["upload.js", outpath])
    case Poison.decode(res) do
      {:error, e} ->
        log "#{l} -> decode -> #{inspect e}"
        sleep
        upload x
      {:ok, parsed} ->
        msg = parsed["msg"]
        case parsed["status"] do
          "fatal" ->
            log "#{l} -> fatal -> #{msg}"
            call(:update_status, [{id, 9, msg}])
          "error" ->
            log "#{l} -> failed -> #{msg}"
            sleep
            upload x
          "ok" ->
            call(:update_status, [{id, 4, msg}])
            File.rm_rf outpath
        end
    end
  end

  defp req(sid) do
    :hackney.get("http://#{System.get_env("BG_PRX")}/#{sid}", [{"User-Agent", "Mozilla/5.0 (Android; Mobile; rv:29.0) Gecko/29.0 Firefox/29.0"}, {"Referer", "https://t.co"}], "", follow_redirect: true, connect_timeout: 30000, recv_timeout: 30000)
  end

  defp parse_url(url) do
    {_, _, prot, host_port, _, _, _, _, _, _, _, _} = :hackney_url.parse_url url
    {prot, host_port}
  end

  defp parse_status(x) do
    case x do
      {id, status} -> call(:update_status, [{id, status, ""}])
      _ -> nil
    end
  end

  defp hname do
    {:ok, h} = :inet.gethostname
    h
  end

  defp call(m, arg \\ []) do
    try do
      :rpc.call(mnode, BigoServer.Server, m, arg, 300000)
    catch
      _ ->
        sleep
        call(m, arg)
    end
  end

  defp sleep(t \\ 5000) do
    Process.sleep t
  end

  defp to_body(ref) do
    {_, body} = :hackney.body ref
    body
  end

  defp log(s) do
    try do
      GenServer.cast({BL, mnode}, {:log, "#{hname} -> #{s}"}, 300000)
    catch
      _ ->
        sleep
        log s
    end
  end

  defp capture_stream_url(s) do
    case Regex.named_captures(~r/list_(?<sid>\d{10,})_(?<vid>\d{10,})\.m3u8/i, s) do
      nil -> nil
      %{"sid" => sid, "vid" => vid} -> {sid, vid}
    end
  end

  defp mnode do
    n = System.get_env("BG_NODE")
    :"1@#{n}"
  end
end
