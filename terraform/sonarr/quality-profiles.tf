# Quality profiles imported from Sonarr API
# Retrieved 2026-05-14 via kubectl exec sonarr /api/v3/qualityprofile
# Sonarr v4 quality sources: television, web, webRip, dvd, bluray, televisionRaw, blurayRaw, unknown
# Note: all 18 quality groups are included in every profile because Sonarr's API always returns
# the full quality list per profile (with per-quality allowed flags). Unlike Radarr, omitting
# non-allowed qualities causes drift on import.

# Profile: Any (id=1) — all qualities allowed except Unknown, Raw-HD, 2160p, upgrade disabled
resource "sonarr_quality_profile" "any" {
  name            = "Any"
  upgrade_allowed = false
  cutoff          = 1 # upgrade_allowed = false, cutoff irrelevant

  quality_groups = [
    {
      name      = "Unknown"
      qualities = [{ id = 0, name = "Unknown", source = "unknown", resolution = 0 }]
    },
    {
      name      = "SDTV"
      qualities = [{ id = 1, name = "SDTV", source = "television", resolution = 480 }]
    },
    {
      id   = 1000
      name = "WEB 480p"
      qualities = [
        { id = 12, name = "WEBRip-480p", source = "webRip", resolution = 480 },
        { id = 8, name = "WEBDL-480p", source = "web", resolution = 480 },
      ]
    },
    {
      name      = "DVD"
      qualities = [{ id = 2, name = "DVD", source = "dvd", resolution = 480 }]
    },
    {
      name      = "Bluray-480p"
      qualities = [{ id = 13, name = "Bluray-480p", source = "bluray", resolution = 480 }]
    },
    {
      name      = "Bluray-576p"
      qualities = [{ id = 22, name = "Bluray-576p", source = "bluray", resolution = 576 }]
    },
    {
      name      = "HDTV-720p"
      qualities = [{ id = 4, name = "HDTV-720p", source = "television", resolution = 720 }]
    },
    {
      name      = "HDTV-1080p"
      qualities = [{ id = 9, name = "HDTV-1080p", source = "television", resolution = 1080 }]
    },
    {
      name      = "Raw-HD"
      qualities = [{ id = 10, name = "Raw-HD", source = "televisionRaw", resolution = 1080 }]
    },
    {
      id   = 1001
      name = "WEB 720p"
      qualities = [
        { id = 14, name = "WEBRip-720p", source = "webRip", resolution = 720 },
        { id = 5, name = "WEBDL-720p", source = "web", resolution = 720 },
      ]
    },
    {
      name      = "Bluray-720p"
      qualities = [{ id = 6, name = "Bluray-720p", source = "bluray", resolution = 720 }]
    },
    {
      id   = 1002
      name = "WEB 1080p"
      qualities = [
        { id = 15, name = "WEBRip-1080p", source = "webRip", resolution = 1080 },
        { id = 3, name = "WEBDL-1080p", source = "web", resolution = 1080 },
      ]
    },
    {
      name      = "Bluray-1080p"
      qualities = [{ id = 7, name = "Bluray-1080p", source = "bluray", resolution = 1080 }]
    },
    {
      name      = "Bluray-1080p Remux"
      qualities = [{ id = 20, name = "Bluray-1080p Remux", source = "blurayRaw", resolution = 1080 }]
    },
    {
      name      = "HDTV-2160p"
      qualities = [{ id = 16, name = "HDTV-2160p", source = "television", resolution = 2160 }]
    },
    {
      id   = 1003
      name = "WEB 2160p"
      qualities = [
        { id = 17, name = "WEBRip-2160p", source = "webRip", resolution = 2160 },
        { id = 18, name = "WEBDL-2160p", source = "web", resolution = 2160 },
      ]
    },
    {
      name      = "Bluray-2160p"
      qualities = [{ id = 19, name = "Bluray-2160p", source = "bluray", resolution = 2160 }]
    },
    {
      name      = "Bluray-2160p Remux"
      qualities = [{ id = 21, name = "Bluray-2160p Remux", source = "blurayRaw", resolution = 2160 }]
    },
  ]
}

# Profile: SD (id=2) — SD qualities allowed (SDTV, WEB 480p, DVD, Bluray 480p/576p), no upgrade
resource "sonarr_quality_profile" "sd" {
  name            = "SD"
  upgrade_allowed = false
  cutoff          = 1 # upgrade_allowed = false, cutoff irrelevant

  quality_groups = [
    {
      name      = "Unknown"
      qualities = [{ id = 0, name = "Unknown", source = "unknown", resolution = 0 }]
    },
    {
      name      = "SDTV"
      qualities = [{ id = 1, name = "SDTV", source = "television", resolution = 480 }]
    },
    {
      id   = 1000
      name = "WEB 480p"
      qualities = [
        { id = 12, name = "WEBRip-480p", source = "webRip", resolution = 480 },
        { id = 8, name = "WEBDL-480p", source = "web", resolution = 480 },
      ]
    },
    {
      name      = "DVD"
      qualities = [{ id = 2, name = "DVD", source = "dvd", resolution = 480 }]
    },
    {
      name      = "Bluray-480p"
      qualities = [{ id = 13, name = "Bluray-480p", source = "bluray", resolution = 480 }]
    },
    {
      name      = "Bluray-576p"
      qualities = [{ id = 22, name = "Bluray-576p", source = "bluray", resolution = 576 }]
    },
    {
      name      = "HDTV-720p"
      qualities = [{ id = 4, name = "HDTV-720p", source = "television", resolution = 720 }]
    },
    {
      name      = "HDTV-1080p"
      qualities = [{ id = 9, name = "HDTV-1080p", source = "television", resolution = 1080 }]
    },
    {
      name      = "Raw-HD"
      qualities = [{ id = 10, name = "Raw-HD", source = "televisionRaw", resolution = 1080 }]
    },
    {
      id   = 1001
      name = "WEB 720p"
      qualities = [
        { id = 14, name = "WEBRip-720p", source = "webRip", resolution = 720 },
        { id = 5, name = "WEBDL-720p", source = "web", resolution = 720 },
      ]
    },
    {
      name      = "Bluray-720p"
      qualities = [{ id = 6, name = "Bluray-720p", source = "bluray", resolution = 720 }]
    },
    {
      id   = 1002
      name = "WEB 1080p"
      qualities = [
        { id = 15, name = "WEBRip-1080p", source = "webRip", resolution = 1080 },
        { id = 3, name = "WEBDL-1080p", source = "web", resolution = 1080 },
      ]
    },
    {
      name      = "Bluray-1080p"
      qualities = [{ id = 7, name = "Bluray-1080p", source = "bluray", resolution = 1080 }]
    },
    {
      name      = "Bluray-1080p Remux"
      qualities = [{ id = 20, name = "Bluray-1080p Remux", source = "blurayRaw", resolution = 1080 }]
    },
    {
      name      = "HDTV-2160p"
      qualities = [{ id = 16, name = "HDTV-2160p", source = "television", resolution = 2160 }]
    },
    {
      id   = 1003
      name = "WEB 2160p"
      qualities = [
        { id = 17, name = "WEBRip-2160p", source = "webRip", resolution = 2160 },
        { id = 18, name = "WEBDL-2160p", source = "web", resolution = 2160 },
      ]
    },
    {
      name      = "Bluray-2160p"
      qualities = [{ id = 19, name = "Bluray-2160p", source = "bluray", resolution = 2160 }]
    },
    {
      name      = "Bluray-2160p Remux"
      qualities = [{ id = 21, name = "Bluray-2160p Remux", source = "blurayRaw", resolution = 2160 }]
    },
  ]
}

# Profile: HD-720p (id=3) — 720p qualities allowed (HDTV-720p, WEB 720p, Bluray-720p), no upgrade
resource "sonarr_quality_profile" "hd_720p" {
  name            = "HD-720p"
  upgrade_allowed = false
  cutoff          = 4 # upgrade_allowed = false, cutoff irrelevant

  quality_groups = [
    {
      name      = "Unknown"
      qualities = [{ id = 0, name = "Unknown", source = "unknown", resolution = 0 }]
    },
    {
      name      = "SDTV"
      qualities = [{ id = 1, name = "SDTV", source = "television", resolution = 480 }]
    },
    {
      id   = 1000
      name = "WEB 480p"
      qualities = [
        { id = 12, name = "WEBRip-480p", source = "webRip", resolution = 480 },
        { id = 8, name = "WEBDL-480p", source = "web", resolution = 480 },
      ]
    },
    {
      name      = "DVD"
      qualities = [{ id = 2, name = "DVD", source = "dvd", resolution = 480 }]
    },
    {
      name      = "Bluray-480p"
      qualities = [{ id = 13, name = "Bluray-480p", source = "bluray", resolution = 480 }]
    },
    {
      name      = "Bluray-576p"
      qualities = [{ id = 22, name = "Bluray-576p", source = "bluray", resolution = 576 }]
    },
    {
      name      = "HDTV-720p"
      qualities = [{ id = 4, name = "HDTV-720p", source = "television", resolution = 720 }]
    },
    {
      name      = "HDTV-1080p"
      qualities = [{ id = 9, name = "HDTV-1080p", source = "television", resolution = 1080 }]
    },
    {
      name      = "Raw-HD"
      qualities = [{ id = 10, name = "Raw-HD", source = "televisionRaw", resolution = 1080 }]
    },
    {
      id   = 1001
      name = "WEB 720p"
      qualities = [
        { id = 14, name = "WEBRip-720p", source = "webRip", resolution = 720 },
        { id = 5, name = "WEBDL-720p", source = "web", resolution = 720 },
      ]
    },
    {
      name      = "Bluray-720p"
      qualities = [{ id = 6, name = "Bluray-720p", source = "bluray", resolution = 720 }]
    },
    {
      id   = 1002
      name = "WEB 1080p"
      qualities = [
        { id = 15, name = "WEBRip-1080p", source = "webRip", resolution = 1080 },
        { id = 3, name = "WEBDL-1080p", source = "web", resolution = 1080 },
      ]
    },
    {
      name      = "Bluray-1080p"
      qualities = [{ id = 7, name = "Bluray-1080p", source = "bluray", resolution = 1080 }]
    },
    {
      name      = "Bluray-1080p Remux"
      qualities = [{ id = 20, name = "Bluray-1080p Remux", source = "blurayRaw", resolution = 1080 }]
    },
    {
      name      = "HDTV-2160p"
      qualities = [{ id = 16, name = "HDTV-2160p", source = "television", resolution = 2160 }]
    },
    {
      id   = 1003
      name = "WEB 2160p"
      qualities = [
        { id = 17, name = "WEBRip-2160p", source = "webRip", resolution = 2160 },
        { id = 18, name = "WEBDL-2160p", source = "web", resolution = 2160 },
      ]
    },
    {
      name      = "Bluray-2160p"
      qualities = [{ id = 19, name = "Bluray-2160p", source = "bluray", resolution = 2160 }]
    },
    {
      name      = "Bluray-2160p Remux"
      qualities = [{ id = 21, name = "Bluray-2160p Remux", source = "blurayRaw", resolution = 2160 }]
    },
  ]
}

# Profile: HD-1080p (id=4) — 1080p qualities allowed (HDTV-1080p, WEB 1080p, Bluray-1080p), no upgrade
resource "sonarr_quality_profile" "hd_1080p" {
  name            = "HD-1080p"
  upgrade_allowed = false
  cutoff          = 9 # upgrade_allowed = false, cutoff irrelevant

  quality_groups = [
    {
      name      = "Unknown"
      qualities = [{ id = 0, name = "Unknown", source = "unknown", resolution = 0 }]
    },
    {
      name      = "SDTV"
      qualities = [{ id = 1, name = "SDTV", source = "television", resolution = 480 }]
    },
    {
      id   = 1000
      name = "WEB 480p"
      qualities = [
        { id = 12, name = "WEBRip-480p", source = "webRip", resolution = 480 },
        { id = 8, name = "WEBDL-480p", source = "web", resolution = 480 },
      ]
    },
    {
      name      = "DVD"
      qualities = [{ id = 2, name = "DVD", source = "dvd", resolution = 480 }]
    },
    {
      name      = "Bluray-480p"
      qualities = [{ id = 13, name = "Bluray-480p", source = "bluray", resolution = 480 }]
    },
    {
      name      = "Bluray-576p"
      qualities = [{ id = 22, name = "Bluray-576p", source = "bluray", resolution = 576 }]
    },
    {
      name      = "HDTV-720p"
      qualities = [{ id = 4, name = "HDTV-720p", source = "television", resolution = 720 }]
    },
    {
      name      = "HDTV-1080p"
      qualities = [{ id = 9, name = "HDTV-1080p", source = "television", resolution = 1080 }]
    },
    {
      name      = "Raw-HD"
      qualities = [{ id = 10, name = "Raw-HD", source = "televisionRaw", resolution = 1080 }]
    },
    {
      id   = 1001
      name = "WEB 720p"
      qualities = [
        { id = 14, name = "WEBRip-720p", source = "webRip", resolution = 720 },
        { id = 5, name = "WEBDL-720p", source = "web", resolution = 720 },
      ]
    },
    {
      name      = "Bluray-720p"
      qualities = [{ id = 6, name = "Bluray-720p", source = "bluray", resolution = 720 }]
    },
    {
      id   = 1002
      name = "WEB 1080p"
      qualities = [
        { id = 15, name = "WEBRip-1080p", source = "webRip", resolution = 1080 },
        { id = 3, name = "WEBDL-1080p", source = "web", resolution = 1080 },
      ]
    },
    {
      name      = "Bluray-1080p"
      qualities = [{ id = 7, name = "Bluray-1080p", source = "bluray", resolution = 1080 }]
    },
    {
      name      = "Bluray-1080p Remux"
      qualities = [{ id = 20, name = "Bluray-1080p Remux", source = "blurayRaw", resolution = 1080 }]
    },
    {
      name      = "HDTV-2160p"
      qualities = [{ id = 16, name = "HDTV-2160p", source = "television", resolution = 2160 }]
    },
    {
      id   = 1003
      name = "WEB 2160p"
      qualities = [
        { id = 17, name = "WEBRip-2160p", source = "webRip", resolution = 2160 },
        { id = 18, name = "WEBDL-2160p", source = "web", resolution = 2160 },
      ]
    },
    {
      name      = "Bluray-2160p"
      qualities = [{ id = 19, name = "Bluray-2160p", source = "bluray", resolution = 2160 }]
    },
    {
      name      = "Bluray-2160p Remux"
      qualities = [{ id = 21, name = "Bluray-2160p Remux", source = "blurayRaw", resolution = 2160 }]
    },
  ]
}

# Profile: Ultra-HD (id=5) — 4K qualities allowed (HDTV-2160p, WEB 2160p, Bluray-2160p), no upgrade
resource "sonarr_quality_profile" "ultra_hd" {
  name            = "Ultra-HD"
  upgrade_allowed = false
  cutoff          = 16 # upgrade_allowed = false, cutoff irrelevant

  quality_groups = [
    {
      name      = "Unknown"
      qualities = [{ id = 0, name = "Unknown", source = "unknown", resolution = 0 }]
    },
    {
      name      = "SDTV"
      qualities = [{ id = 1, name = "SDTV", source = "television", resolution = 480 }]
    },
    {
      id   = 1000
      name = "WEB 480p"
      qualities = [
        { id = 12, name = "WEBRip-480p", source = "webRip", resolution = 480 },
        { id = 8, name = "WEBDL-480p", source = "web", resolution = 480 },
      ]
    },
    {
      name      = "DVD"
      qualities = [{ id = 2, name = "DVD", source = "dvd", resolution = 480 }]
    },
    {
      name      = "Bluray-480p"
      qualities = [{ id = 13, name = "Bluray-480p", source = "bluray", resolution = 480 }]
    },
    {
      name      = "Bluray-576p"
      qualities = [{ id = 22, name = "Bluray-576p", source = "bluray", resolution = 576 }]
    },
    {
      name      = "HDTV-720p"
      qualities = [{ id = 4, name = "HDTV-720p", source = "television", resolution = 720 }]
    },
    {
      name      = "HDTV-1080p"
      qualities = [{ id = 9, name = "HDTV-1080p", source = "television", resolution = 1080 }]
    },
    {
      name      = "Raw-HD"
      qualities = [{ id = 10, name = "Raw-HD", source = "televisionRaw", resolution = 1080 }]
    },
    {
      id   = 1001
      name = "WEB 720p"
      qualities = [
        { id = 14, name = "WEBRip-720p", source = "webRip", resolution = 720 },
        { id = 5, name = "WEBDL-720p", source = "web", resolution = 720 },
      ]
    },
    {
      name      = "Bluray-720p"
      qualities = [{ id = 6, name = "Bluray-720p", source = "bluray", resolution = 720 }]
    },
    {
      id   = 1002
      name = "WEB 1080p"
      qualities = [
        { id = 15, name = "WEBRip-1080p", source = "webRip", resolution = 1080 },
        { id = 3, name = "WEBDL-1080p", source = "web", resolution = 1080 },
      ]
    },
    {
      name      = "Bluray-1080p"
      qualities = [{ id = 7, name = "Bluray-1080p", source = "bluray", resolution = 1080 }]
    },
    {
      name      = "Bluray-1080p Remux"
      qualities = [{ id = 20, name = "Bluray-1080p Remux", source = "blurayRaw", resolution = 1080 }]
    },
    {
      name      = "HDTV-2160p"
      qualities = [{ id = 16, name = "HDTV-2160p", source = "television", resolution = 2160 }]
    },
    {
      id   = 1003
      name = "WEB 2160p"
      qualities = [
        { id = 17, name = "WEBRip-2160p", source = "webRip", resolution = 2160 },
        { id = 18, name = "WEBDL-2160p", source = "web", resolution = 2160 },
      ]
    },
    {
      name      = "Bluray-2160p"
      qualities = [{ id = 19, name = "Bluray-2160p", source = "bluray", resolution = 2160 }]
    },
    {
      name      = "Bluray-2160p Remux"
      qualities = [{ id = 21, name = "Bluray-2160p Remux", source = "blurayRaw", resolution = 2160 }]
    },
  ]
}

# Profile: HD - 720p/1080p (id=6) — 720p and 1080p qualities allowed, no upgrade
resource "sonarr_quality_profile" "hd_720p_1080p" {
  name            = "HD - 720p/1080p"
  upgrade_allowed = false
  cutoff          = 4 # upgrade_allowed = false, cutoff irrelevant

  quality_groups = [
    {
      name      = "Unknown"
      qualities = [{ id = 0, name = "Unknown", source = "unknown", resolution = 0 }]
    },
    {
      name      = "SDTV"
      qualities = [{ id = 1, name = "SDTV", source = "television", resolution = 480 }]
    },
    {
      id   = 1000
      name = "WEB 480p"
      qualities = [
        { id = 12, name = "WEBRip-480p", source = "webRip", resolution = 480 },
        { id = 8, name = "WEBDL-480p", source = "web", resolution = 480 },
      ]
    },
    {
      name      = "DVD"
      qualities = [{ id = 2, name = "DVD", source = "dvd", resolution = 480 }]
    },
    {
      name      = "Bluray-480p"
      qualities = [{ id = 13, name = "Bluray-480p", source = "bluray", resolution = 480 }]
    },
    {
      name      = "Bluray-576p"
      qualities = [{ id = 22, name = "Bluray-576p", source = "bluray", resolution = 576 }]
    },
    {
      name      = "HDTV-720p"
      qualities = [{ id = 4, name = "HDTV-720p", source = "television", resolution = 720 }]
    },
    {
      name      = "HDTV-1080p"
      qualities = [{ id = 9, name = "HDTV-1080p", source = "television", resolution = 1080 }]
    },
    {
      name      = "Raw-HD"
      qualities = [{ id = 10, name = "Raw-HD", source = "televisionRaw", resolution = 1080 }]
    },
    {
      id   = 1001
      name = "WEB 720p"
      qualities = [
        { id = 14, name = "WEBRip-720p", source = "webRip", resolution = 720 },
        { id = 5, name = "WEBDL-720p", source = "web", resolution = 720 },
      ]
    },
    {
      name      = "Bluray-720p"
      qualities = [{ id = 6, name = "Bluray-720p", source = "bluray", resolution = 720 }]
    },
    {
      id   = 1002
      name = "WEB 1080p"
      qualities = [
        { id = 15, name = "WEBRip-1080p", source = "webRip", resolution = 1080 },
        { id = 3, name = "WEBDL-1080p", source = "web", resolution = 1080 },
      ]
    },
    {
      name      = "Bluray-1080p"
      qualities = [{ id = 7, name = "Bluray-1080p", source = "bluray", resolution = 1080 }]
    },
    {
      name      = "Bluray-1080p Remux"
      qualities = [{ id = 20, name = "Bluray-1080p Remux", source = "blurayRaw", resolution = 1080 }]
    },
    {
      name      = "HDTV-2160p"
      qualities = [{ id = 16, name = "HDTV-2160p", source = "television", resolution = 2160 }]
    },
    {
      id   = 1003
      name = "WEB 2160p"
      qualities = [
        { id = 17, name = "WEBRip-2160p", source = "webRip", resolution = 2160 },
        { id = 18, name = "WEBDL-2160p", source = "web", resolution = 2160 },
      ]
    },
    {
      name      = "Bluray-2160p"
      qualities = [{ id = 19, name = "Bluray-2160p", source = "bluray", resolution = 2160 }]
    },
    {
      name      = "Bluray-2160p Remux"
      qualities = [{ id = 21, name = "Bluray-2160p Remux", source = "blurayRaw", resolution = 2160 }]
    },
  ]
}
