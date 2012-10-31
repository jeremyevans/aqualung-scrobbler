dofile(os.getenv("HOME") .. "/.aqualung/scrobbler_config.lua")

Aqualung.scrobbler.previous_file = {}
Aqualung.scrobbler.keys = {'track', 'artist', 'album', 'trackNumber', 'duration', 'timestamp'}

function shell_escape(s)
  s:gsub("'","'\\''")
  return s
end

function url_encode(str)
  if (str) then
    str = string.gsub (str, "\n", "\r\n")
    str = string.gsub (str, "([^%w ])", function (c) return string.format ("%%%02X", string.byte(c)) end)
    str = string.gsub (str, " ", "+")
  end
  return str  
end

function scrobble_params()
  local param_string = ''
  local sig_input = ''
  local params = {}
  local sorted_params_keys = {}

  params.sk = Aqualung.scrobbler.session_key
  params.api_key = Aqualung.scrobbler.api_key
  params.method = 'track.scrobble'
  for i, k in ipairs(Aqualung.scrobbler.keys) do
    params[k] = Aqualung.scrobbler.previous_file[k]
  end

  for k, v in pairs(params) do
    if v ~= "" then
      table.insert(sorted_params_keys, k)
    end
  end
  table.sort(sorted_params_keys)

  for i, k in ipairs(sorted_params_keys) do
    local v = params[k]
    if param_string ~= "" then
      param_string = param_string .. "&"
    end
    param_string = param_string ..  url_encode(k) .. "=" .. url_encode(v)
    sig_input = sig_input .. k .. v
  end
  return shell_escape(param_string) .. "&api_sig='`" .. Aqualung.scrobbler.md5 .. " '" .. shell_escape(sig_input .. Aqualung.scrobbler.api_secret) .. "'`"
end

function scrobble()
 os.execute(Aqualung.scrobbler.curl .. " -d '" .. scrobble_params() .. " " .. Aqualung.scrobbler.endpoint .. " >/dev/null &")
end

function set_previous_file_info()
  local pf = Aqualung.scrobbler.previous_file
  pf.track = m("title")
  pf.artist = m("artist")
  pf.album = m("album")
  pf.trackNumber = m("trackno")
  pf.duration = math.floor(i("samples")/i("sample_rate"))
end

function check_scrobble()
  local current_time = os.time()
  local pf = Aqualung.scrobbler.previous_file
  if pf.timestamp and
     pf.track ~= "" and
     pf.artist ~= "" and
     pf.duration and
     pf.duration > 30 and
     current_time - pf.timestamp > pf.duration/2 then
    scrobble()
  end
  pf.timestamp = current_time
  set_previous_file_info()
end

add_hook("track_change", check_scrobble)
