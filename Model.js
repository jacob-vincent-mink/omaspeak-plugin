.pragma library

function parseStatus(raw) {
  try {
    var text = raw === null || raw === undefined ? "{}" : String(raw)
    return JSON.parse(text || "{}")
  } catch (e) { return null }
}

function parseVoices(raw) {
  try {
    var parsed = JSON.parse(String(raw || "[]"))
    return Array.isArray(parsed) ? parsed : []
  } catch (e) { return [] }
}

function isDaemonRunning(statusData) {
  return !!(statusData && statusData.running === true)
}

function modelName(statusData) {
  return statusData && statusData.model ? statusData.model : ""
}

function backendName(statusData) {
  if (!statusData || !statusData.backend) return ""
  if (statusData.backend.requested) {
    return statusData.backend.requested.runtime + " / " + statusData.backend.requested.device
  }
  return statusData.backend.kind || ""
}

function parseUnitLoadState(raw) {
  return String(raw || "").trim() === "loaded"
}

function activeVoiceId(statusData) {
  if (!statusData || !statusData.backend || !statusData.backend.requests) return -1
  var active = statusData.backend.requests.active
  return active && active.voice !== undefined ? active.voice : -1
}
