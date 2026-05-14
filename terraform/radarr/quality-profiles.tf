# Quality profiles imported from Radarr API
# Retrieved 2026-05-14 via kubectl exec radarr /api/v3/qualityprofile
# language id=1 = English

# Profile: Any (id=1) — all qualities allowed, no upgrade
resource "radarr_quality_profile" "any" {
  name            = "Any"
  upgrade_allowed = false
  cutoff          = 20 # Bluray-1080p

  language = {
    id = 1
  }

  quality_groups = [
    {
      name      = "WORKPRINT"
      qualities = [{ id = 24, name = "WORKPRINT", source = "workprint", resolution = 0 }]
    },
    {
      name      = "CAM"
      qualities = [{ id = 25, name = "CAM", source = "cam", resolution = 0 }]
    },
    {
      name      = "TELESYNC"
      qualities = [{ id = 26, name = "TELESYNC", source = "telesync", resolution = 0 }]
    },
    {
      name      = "TELECINE"
      qualities = [{ id = 27, name = "TELECINE", source = "telecine", resolution = 0 }]
    },
    {
      name      = "REGIONAL"
      qualities = [{ id = 29, name = "REGIONAL", source = "dvd", resolution = 480 }]
    },
    {
      name      = "DVDSCR"
      qualities = [{ id = 28, name = "DVDSCR", source = "dvd", resolution = 480 }]
    },
    {
      name      = "SDTV"
      qualities = [{ id = 1, name = "SDTV", source = "tv", resolution = 480 }]
    },
    {
      name      = "DVD"
      qualities = [{ id = 2, name = "DVD", source = "dvd", resolution = 0 }]
    },
    {
      name      = "DVD-R"
      qualities = [{ id = 23, name = "DVD-R", source = "dvd", resolution = 480 }]
    },
    {
      id        = 1000
      name      = "WEB 480p"
      qualities = [
        { id = 8, name = "WEBDL-480p", source = "webdl", resolution = 480 },
        { id = 12, name = "WEBRip-480p", source = "webrip", resolution = 480 },
      ]
    },
    {
      name      = "Bluray-480p"
      qualities = [{ id = 20, name = "Bluray-480p", source = "bluray", resolution = 480 }]
    },
    {
      name      = "Bluray-576p"
      qualities = [{ id = 21, name = "Bluray-576p", source = "bluray", resolution = 576 }]
    },
    {
      name      = "HDTV-720p"
      qualities = [{ id = 4, name = "HDTV-720p", source = "tv", resolution = 720 }]
    },
    {
      id        = 1001
      name      = "WEB 720p"
      qualities = [
        { id = 5, name = "WEBDL-720p", source = "webdl", resolution = 720 },
        { id = 14, name = "WEBRip-720p", source = "webrip", resolution = 720 },
      ]
    },
    {
      name      = "Bluray-720p"
      qualities = [{ id = 6, name = "Bluray-720p", source = "bluray", resolution = 720 }]
    },
    {
      name      = "HDTV-1080p"
      qualities = [{ id = 9, name = "HDTV-1080p", source = "tv", resolution = 1080 }]
    },
    {
      id        = 1002
      name      = "WEB 1080p"
      qualities = [
        { id = 3, name = "WEBDL-1080p", source = "webdl", resolution = 1080 },
        { id = 15, name = "WEBRip-1080p", source = "webrip", resolution = 1080 },
      ]
    },
    {
      name      = "Bluray-1080p"
      qualities = [{ id = 7, name = "Bluray-1080p", source = "bluray", resolution = 1080 }]
    },
    {
      name      = "Remux-1080p"
      qualities = [{ id = 30, name = "Remux-1080p", source = "bluray", resolution = 1080 }]
    },
    {
      name      = "HDTV-2160p"
      qualities = [{ id = 16, name = "HDTV-2160p", source = "tv", resolution = 2160 }]
    },
    {
      id        = 1003
      name      = "WEB 2160p"
      qualities = [
        { id = 18, name = "WEBDL-2160p", source = "webdl", resolution = 2160 },
        { id = 17, name = "WEBRip-2160p", source = "webrip", resolution = 2160 },
      ]
    },
    {
      name      = "Bluray-2160p"
      qualities = [{ id = 19, name = "Bluray-2160p", source = "bluray", resolution = 2160 }]
    },
    {
      name      = "Remux-2160p"
      qualities = [{ id = 31, name = "Remux-2160p", source = "bluray", resolution = 2160 }]
    },
  ]
}

# Profile: SD (id=2) — SD and WEB 480p / Bluray 480p/576p allowed, no upgrade
resource "radarr_quality_profile" "sd" {
  name            = "SD"
  upgrade_allowed = false
  cutoff          = 20 # upgrade_allowed = false, so cutoff is irrelevant

  language = {
    id = 1
  }

  quality_groups = [
    {
      name      = "WORKPRINT"
      qualities = [{ id = 24, name = "WORKPRINT", source = "workprint", resolution = 0 }]
    },
    {
      name      = "CAM"
      qualities = [{ id = 25, name = "CAM", source = "cam", resolution = 0 }]
    },
    {
      name      = "TELESYNC"
      qualities = [{ id = 26, name = "TELESYNC", source = "telesync", resolution = 0 }]
    },
    {
      name      = "TELECINE"
      qualities = [{ id = 27, name = "TELECINE", source = "telecine", resolution = 0 }]
    },
    {
      name      = "REGIONAL"
      qualities = [{ id = 29, name = "REGIONAL", source = "dvd", resolution = 480 }]
    },
    {
      name      = "DVDSCR"
      qualities = [{ id = 28, name = "DVDSCR", source = "dvd", resolution = 480 }]
    },
    {
      name      = "SDTV"
      qualities = [{ id = 1, name = "SDTV", source = "tv", resolution = 480 }]
    },
    {
      name      = "DVD"
      qualities = [{ id = 2, name = "DVD", source = "dvd", resolution = 0 }]
    },
    {
      id        = 1000
      name      = "WEB 480p"
      qualities = [
        { id = 8, name = "WEBDL-480p", source = "webdl", resolution = 480 },
        { id = 12, name = "WEBRip-480p", source = "webrip", resolution = 480 },
      ]
    },
    {
      name      = "Bluray-480p"
      qualities = [{ id = 20, name = "Bluray-480p", source = "bluray", resolution = 480 }]
    },
    {
      name      = "Bluray-576p"
      qualities = [{ id = 21, name = "Bluray-576p", source = "bluray", resolution = 576 }]
    },
  ]
}

# Profile: HD-720p (id=3) — 720p qualities only, no upgrade
resource "radarr_quality_profile" "hd_720p" {
  name            = "HD-720p"
  upgrade_allowed = false
  cutoff          = 6 # Bluray-720p

  language = {
    id = 1
  }

  quality_groups = [
    {
      name      = "HDTV-720p"
      qualities = [{ id = 4, name = "HDTV-720p", source = "tv", resolution = 720 }]
    },
    {
      id        = 1001
      name      = "WEB 720p"
      qualities = [
        { id = 5, name = "WEBDL-720p", source = "webdl", resolution = 720 },
        { id = 14, name = "WEBRip-720p", source = "webrip", resolution = 720 },
      ]
    },
    {
      name      = "Bluray-720p"
      qualities = [{ id = 6, name = "Bluray-720p", source = "bluray", resolution = 720 }]
    },
  ]
}

# Profile: HD-1080p (id=4) — 1080p qualities only, no upgrade
resource "radarr_quality_profile" "hd_1080p" {
  name            = "HD-1080p"
  upgrade_allowed = false
  cutoff          = 7 # Bluray-1080p

  language = {
    id = 1
  }

  quality_groups = [
    {
      name      = "HDTV-1080p"
      qualities = [{ id = 9, name = "HDTV-1080p", source = "tv", resolution = 1080 }]
    },
    {
      id        = 1002
      name      = "WEB 1080p"
      qualities = [
        { id = 3, name = "WEBDL-1080p", source = "webdl", resolution = 1080 },
        { id = 15, name = "WEBRip-1080p", source = "webrip", resolution = 1080 },
      ]
    },
    {
      name      = "Bluray-1080p"
      qualities = [{ id = 7, name = "Bluray-1080p", source = "bluray", resolution = 1080 }]
    },
    {
      name      = "Remux-1080p"
      qualities = [{ id = 30, name = "Remux-1080p", source = "bluray", resolution = 1080 }]
    },
  ]
}

# Profile: Ultra-HD (id=5) — 4K qualities only, no upgrade
resource "radarr_quality_profile" "ultra_hd" {
  name            = "Ultra-HD"
  upgrade_allowed = false
  cutoff          = 31 # Remux-2160p

  language = {
    id = 1
  }

  quality_groups = [
    {
      name      = "HDTV-2160p"
      qualities = [{ id = 16, name = "HDTV-2160p", source = "tv", resolution = 2160 }]
    },
    {
      id        = 1003
      name      = "WEB 2160p"
      qualities = [
        { id = 18, name = "WEBDL-2160p", source = "webdl", resolution = 2160 },
        { id = 17, name = "WEBRip-2160p", source = "webrip", resolution = 2160 },
      ]
    },
    {
      name      = "Bluray-2160p"
      qualities = [{ id = 19, name = "Bluray-2160p", source = "bluray", resolution = 2160 }]
    },
    {
      name      = "Remux-2160p"
      qualities = [{ id = 31, name = "Remux-2160p", source = "bluray", resolution = 2160 }]
    },
  ]
}

# Profile: HD - 720p/1080p (id=6) — 720p and 1080p qualities, no upgrade
resource "radarr_quality_profile" "hd_720p_1080p" {
  name            = "HD - 720p/1080p"
  upgrade_allowed = false
  cutoff          = 6 # Bluray-720p

  language = {
    id = 1
  }

  quality_groups = [
    {
      name      = "HDTV-720p"
      qualities = [{ id = 4, name = "HDTV-720p", source = "tv", resolution = 720 }]
    },
    {
      id        = 1001
      name      = "WEB 720p"
      qualities = [
        { id = 5, name = "WEBDL-720p", source = "webdl", resolution = 720 },
        { id = 14, name = "WEBRip-720p", source = "webrip", resolution = 720 },
      ]
    },
    {
      name      = "Bluray-720p"
      qualities = [{ id = 6, name = "Bluray-720p", source = "bluray", resolution = 720 }]
    },
    {
      name      = "HDTV-1080p"
      qualities = [{ id = 9, name = "HDTV-1080p", source = "tv", resolution = 1080 }]
    },
    {
      id        = 1002
      name      = "WEB 1080p"
      qualities = [
        { id = 3, name = "WEBDL-1080p", source = "webdl", resolution = 1080 },
        { id = 15, name = "WEBRip-1080p", source = "webrip", resolution = 1080 },
      ]
    },
    {
      name      = "Bluray-1080p"
      qualities = [{ id = 7, name = "Bluray-1080p", source = "bluray", resolution = 1080 }]
    },
    {
      name      = "Remux-1080p"
      qualities = [{ id = 30, name = "Remux-1080p", source = "bluray", resolution = 1080 }]
    },
  ]
}
