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

  // --- Matrix-style background (hero only) ---
  function startMatrix(canvas) {
    if (!canvas) return;
    if (window.matchMedia && window.matchMedia("(prefers-reduced-motion: reduce)").matches) {
      return;
    }
    var ctx = canvas.getContext("2d");
    if (!ctx) return;

    var dpr = Math.max(1, Math.min(2, window.devicePixelRatio || 1));
    var cols = 0;
    var drops = [];
    var raf = 0;

    function resize() {
      var w = canvas.clientWidth || canvas.parentElement.clientWidth || window.innerWidth;
      var h = canvas.clientHeight || canvas.parentElement.clientHeight || 420;
      canvas.width = Math.floor(w * dpr);
      canvas.height = Math.floor(h * dpr);
      ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
      cols = Math.floor(w / 14);
      drops = new Array(cols).fill(0).map(function () {
        return Math.random() * h;
      });
    }

    function step() {
      var w = canvas.clientWidth || window.innerWidth;
      var h = canvas.clientHeight || 420;
      ctx.fillStyle = "rgba(12, 18, 34, 0.18)";
      ctx.fillRect(0, 0, w, h);

      ctx.font = "12px ui-monospace, SFMono-Regular, Menlo, Consolas, monospace";
      for (var i = 0; i < drops.length; i++) {
        var x = i * 14 + 6;
        var y = drops[i];
        // Soft aqua/purple palette to match the hero gradients (not pure green).
        var hue = (190 + (i % 6) * 18) % 360;
        ctx.fillStyle = "hsla(" + hue + ", 90%, 70%, 0.75)";
        var code = 0x30A0 + Math.floor(Math.random() * 96);
        ctx.fillText(String.fromCharCode(code), x, y);
        drops[i] = y + 14 + Math.random() * 10;
        if (drops[i] > h + 40 && Math.random() > 0.975) {
          drops[i] = -Math.random() * 120;
        }
      }
      raf = window.requestAnimationFrame(step);
    }

    resize();
    step();

    window.addEventListener("resize", resize, { passive: true });
    return function stop() {
      window.cancelAnimationFrame(raf);
    };
  }

  // --- Subtle 3D tilt (hero mock + cards) ---
  function wireTilt(el) {
    if (!el) return;
    if (window.matchMedia && window.matchMedia("(prefers-reduced-motion: reduce)").matches) {
      return;
    }
    var inner = el.querySelector(".showcase-frame") || el;
    var max = 8; // degrees

    function onMove(e) {
      var rect = el.getBoundingClientRect();
      var x = (e.clientX - rect.left) / rect.width;
      var y = (e.clientY - rect.top) / rect.height;
      var rx = (0.5 - y) * max;
      var ry = (x - 0.5) * max;
      inner.style.transform = "rotateX(" + rx.toFixed(2) + "deg) rotateY(" + ry.toFixed(2) + "deg)";
    }

    function reset() {
      inner.style.transform = "rotateX(0deg) rotateY(0deg)";
    }

    el.addEventListener("pointermove", onMove, { passive: true });
    el.addEventListener("pointerleave", reset, { passive: true });
    el.addEventListener("pointerdown", reset, { passive: true });
  }

  startMatrix(document.querySelector("[data-matrix]"));
  document.querySelectorAll("[data-tilt]").forEach(wireTilt);
})();
