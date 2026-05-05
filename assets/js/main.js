(function () {
  "use strict";

  function repoSlug() {
    return window.SENTRACORE_GITHUB || "AsieduDevelopmentHub/SentraCore";
  }

  function releasesLatestUrl() {
    return "https://github.com/" + repoSlug() + "/releases/latest";
  }

  function githubRepoUrl() {
    return "https://github.com/" + repoSlug();
  }

  function apiLatestReleaseUrl() {
    return "https://api.github.com/repos/" + repoSlug() + "/releases/latest";
  }

  document.querySelectorAll("[data-github-repo-link]").forEach(function (el) {
    el.setAttribute("href", githubRepoUrl());
  });

  /** Pick CI artifact from GitHub release assets (matches workflow output names). */
  function pickAsset(assets, platform) {
    var list = assets || [];
    var a;
    var i;
    if (platform === "windows") {
      for (i = 0; i < list.length; i++) {
        a = list[i];
        if (/\.exe$/i.test(a.name) && /Setup|setup|sentracore/i.test(a.name)) return a;
      }
      for (i = 0; i < list.length; i++) {
        a = list[i];
        if (/\.exe$/i.test(a.name)) return a;
      }
    }
    if (platform === "macos") {
      for (i = 0; i < list.length; i++) {
        a = list[i];
        if (/\.zip$/i.test(a.name) && /macos|macOS/i.test(a.name)) return a;
      }
      for (i = 0; i < list.length; i++) {
        a = list[i];
        if (/\.zip$/i.test(a.name) && !/windows|\.exe/i.test(a.name)) return a;
      }
    }
    if (platform === "linux") {
      for (i = 0; i < list.length; i++) {
        a = list[i];
        if (/\.AppImage$/i.test(a.name)) return a;
      }
    }
    return null;
  }

  document.querySelectorAll("[data-releases-link]").forEach(function (el) {
    if (!el.hasAttribute("data-auto-download")) {
      el.setAttribute("href", releasesLatestUrl());
    }
  });

  var toggle = document.querySelector("[data-nav-toggle]");
  var panel = document.querySelector("[data-nav-panel]");
  if (toggle && panel) {
    toggle.addEventListener("click", function () {
      var open = panel.classList.toggle("is-open");
      toggle.setAttribute("aria-expanded", open ? "true" : "false");
    });
  }

  document.querySelectorAll('a[href^="#"]').forEach(function (anchor) {
    anchor.addEventListener("click", function (e) {
      var id = anchor.getAttribute("href").slice(1);
      if (!id) return;
      var target = document.getElementById(id);
      if (target) {
        e.preventDefault();
        target.scrollIntoView({ behavior: "smooth", block: "start" });
        if (panel) panel.classList.remove("is-open");
      }
    });
  });

  document.querySelectorAll("[data-download-track]").forEach(function (btn) {
    btn.addEventListener("click", function () {
      var platform = btn.getAttribute("data-download-track") || "unknown";
      if (window.console && console.log) {
        console.log("[SentraCore] download click:", platform);
      }
    });
  });

  async function wireDirectDownloads() {
    var holders = document.querySelectorAll("[data-auto-download]");
    if (!holders.length) return;

    holders.forEach(function (el) {
      el.classList.add("btn--pending");
    });

    try {
      var res = await fetch(apiLatestReleaseUrl(), {
        headers: { Accept: "application/vnd.github+json" },
      });
      if (!res.ok) throw new Error("GitHub API " + res.status);
      var rel = await res.json();
      var assets = rel.assets || [];

      holders.forEach(function (el) {
        var platform = el.getAttribute("data-auto-download");
        var asset = pickAsset(assets, platform);
        el.classList.remove("btn--pending");
        if (asset && asset.browser_download_url) {
          el.setAttribute("href", asset.browser_download_url);
          el.setAttribute("rel", "nofollow noopener");
          el.removeAttribute("target");
        } else {
          el.setAttribute("href", releasesLatestUrl());
        }
      });

      var tagEls = document.querySelectorAll("[data-latest-tag]");
      var tag = rel.tag_name || rel.name || "";
      tagEls.forEach(function (node) {
        node.textContent = tag || "—";
      });
    } catch (err) {
      if (window.console && console.warn) {
        console.warn("[SentraCore] Direct download fallback:", err.message || err);
      }
      holders.forEach(function (el) {
        el.classList.remove("btn--pending");
        el.setAttribute("href", releasesLatestUrl());
      });
    }
  }

  wireDirectDownloads();
})();
