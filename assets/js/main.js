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
    btn.addEventListener("click", function () {});
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
      holders.forEach(function (el) {
        el.classList.remove("btn--pending");
        el.setAttribute("href", releasesLatestUrl());
      });
    }
  }

  wireDirectDownloads();

  function prefersReducedMotion() {
    return window.matchMedia && window.matchMedia("(prefers-reduced-motion: reduce)").matches;
  }

  function initGsapAnimations() {
    var gsap = window.gsap;
    var ST = window.ScrollTrigger;
    if (!gsap || !ST) return;
    gsap.registerPlugin(ST);
    if (prefersReducedMotion()) return;

    var heroCopy = document.getElementById("hero-copy");
    var heroVisual = document.getElementById("hero-visual");
    if (heroCopy && heroVisual) {
      gsap.set(heroVisual, { opacity: 0, x: 36, scale: 0.96 });
      var badge = heroCopy.querySelector(".hero-badge");
      var title = heroCopy.querySelector("h1");
      var lead = heroCopy.querySelector(".hero-lead");
      var actions = heroCopy.querySelector(".hero-actions");
      if (badge) gsap.set(badge, { opacity: 0, y: 20 });
      if (title) gsap.set(title, { opacity: 0, y: 24 });
      if (lead) gsap.set(lead, { opacity: 0, y: 20 });
      if (actions) gsap.set(actions, { opacity: 0, y: 16 });

      var tl = gsap.timeline({ defaults: { ease: "power3.out" } });
      if (badge) tl.to(badge, { opacity: 1, y: 0, duration: 0.5 }, 0);
      if (title) tl.to(title, { opacity: 1, y: 0, duration: 0.65 }, 0.08);
      if (lead) tl.to(lead, { opacity: 1, y: 0, duration: 0.55 }, 0.18);
      if (actions) tl.to(actions, { opacity: 1, y: 0, duration: 0.5 }, 0.28);
      tl.to(heroVisual, { opacity: 1, x: 0, scale: 1, duration: 0.85 }, 0.12);
    }

    var homeIntro = document.querySelector(".home-intro-grid");
    if (homeIntro) {
      gsap.from(homeIntro.children, {
        scrollTrigger: { trigger: homeIntro, start: "top 82%" },
        y: 36,
        opacity: 0,
        duration: 0.6,
        stagger: 0.12,
        ease: "power2.out",
      });
    }

    var pillarsHead = document.getElementById("section-pillars-head");
    if (pillarsHead) {
      gsap.from(pillarsHead.children, {
        scrollTrigger: { trigger: pillarsHead, start: "top 85%" },
        y: 24,
        opacity: 0,
        duration: 0.5,
        stagger: 0.1,
        ease: "power2.out",
      });
    }

    var pillarCards = document.querySelectorAll("[data-reveal-pillar]");
    if (pillarCards.length) {
      gsap.from(pillarCards, {
        scrollTrigger: { trigger: "#pillar-grid", start: "top 86%" },
        y: 28,
        opacity: 0,
        duration: 0.5,
        stagger: 0.1,
        ease: "power2.out",
      });
    }

    var homeCtaInner = document.querySelector(".home-cta-inner");
    if (homeCtaInner) {
      gsap.from(homeCtaInner.children, {
        scrollTrigger: { trigger: homeCtaInner, start: "top 88%" },
        y: 22,
        opacity: 0,
        duration: 0.5,
        stagger: 0.1,
        ease: "power2.out",
      });
    }

    var sectionHead = document.getElementById("section-features-head");
    if (sectionHead) {
      gsap.from(sectionHead.children, {
        scrollTrigger: { trigger: sectionHead, start: "top 82%" },
        y: 28,
        opacity: 0,
        duration: 0.55,
        stagger: 0.1,
        ease: "power2.out",
      });
    }

    var cards = document.querySelectorAll("[data-reveal-card]");
    if (cards.length) {
      gsap.from(cards, {
        scrollTrigger: { trigger: "#feature-grid", start: "top 85%" },
        y: 32,
        opacity: 0,
        duration: 0.55,
        stagger: 0.08,
        ease: "power2.out",
      });
    }

    gsap.utils.toArray(".page-reveal").forEach(function (el) {
      gsap.from(el, {
        scrollTrigger: { trigger: el, start: "top 88%" },
        y: 24,
        opacity: 0,
        duration: 0.5,
        ease: "power2.out",
      });
    });
  }

  function startMatrix(canvas) {
    if (!canvas) return;
    if (prefersReducedMotion()) return;
    var ctx = canvas.getContext("2d");
    if (!ctx) return;

    var pageBg = canvas.classList.contains("matrix-canvas--page-bg");
    var cell = 16;
    var dpr = Math.max(1, Math.min(2.25, window.devicePixelRatio || 1));
    var cols = 0;
    var drops = [];
    var raf = 0;

    function viewportSize() {
      return {
        w: window.innerWidth || document.documentElement.clientWidth || 800,
        h: window.innerHeight || document.documentElement.clientHeight || 600,
      };
    }

    function resize() {
      var w;
      var h;
      if (pageBg) {
        var v = viewportSize();
        w = v.w;
        h = v.h;
        canvas.style.width = w + "px";
        canvas.style.height = h + "px";
      } else {
        w = canvas.clientWidth || canvas.parentElement.clientWidth || window.innerWidth;
        h = canvas.clientHeight || canvas.parentElement.clientHeight || 420;
      }
      canvas.width = Math.floor(w * dpr);
      canvas.height = Math.floor(h * dpr);
      ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
      cols = Math.max(8, Math.floor(w / cell));
      drops = new Array(cols).fill(0).map(function () {
        return Math.random() * h;
      });
    }

    function step() {
      var v = viewportSize();
      var w = pageBg ? v.w : canvas.clientWidth || v.w;
      var h = pageBg ? v.h : canvas.clientHeight || 420;
      /* Fade trails toward “paper” so multiply blend keeps gutters feeling light */
      ctx.fillStyle = pageBg ? "rgba(255, 255, 255, 0.14)" : "rgba(3, 7, 18, 0.07)";
      ctx.fillRect(0, 0, w, h);

      ctx.font =
        "bold 15px ui-monospace, SFMono-Regular, Menlo, Consolas, 'Cascadia Code', monospace";
      for (var i = 0; i < drops.length; i++) {
        var x = i * cell + Math.floor(cell * 0.35);
        var y = drops[i];
        /* Near-black with a hint of matrix green; reads black on white after multiply */
        var l = 0.08 + (i % 5) * 0.018;
        var a = pageBg ? 0.82 : 0.92;
        ctx.fillStyle = "hsla(135, 35%, " + Math.round(l * 100) + "%, " + a + ")";
        var code = 0x30a0 + Math.floor(Math.random() * 96);
        ctx.fillText(String.fromCharCode(code), x, y);
        drops[i] = y + cell * 0.85 + Math.random() * 12;
        if (drops[i] > h + 48 && Math.random() > 0.965) {
          drops[i] = -Math.random() * (h * 0.35);
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

  function wireTilt(el) {
    if (!el) return;
    if (prefersReducedMotion()) return;
    var inner =
      el.querySelector(".hero-visual-frame") ||
      el.querySelector(".showcase-frame") ||
      el;
    var max = 8;

    function onMove(e) {
      var rect = el.getBoundingClientRect();
      var x = (e.clientX - rect.left) / rect.width;
      var y = (e.clientY - rect.top) / rect.height;
      var rx = (0.5 - y) * max;
      var ry = (x - 0.5) * max;
      inner.style.transform =
        "rotateX(" + rx.toFixed(2) + "deg) rotateY(" + ry.toFixed(2) + "deg)";
    }

    function reset() {
      inner.style.transform = "rotateX(0deg) rotateY(0deg)";
    }

    el.addEventListener("pointermove", onMove, { passive: true });
    el.addEventListener("pointerleave", reset, { passive: true });
    el.addEventListener("pointerdown", reset, { passive: true });
  }

  function wireDashboardPreview() {
    document.querySelectorAll("[data-dashboard-preview]").forEach(function (fig) {
      var img = fig.querySelector("[data-dashboard-preview-img]");
      if (!img) return;
      function showImage() {
        if (img.naturalWidth > 0) fig.classList.remove("dashboard-preview--no-image");
      }
      function showFallback() {
        fig.classList.add("dashboard-preview--no-image");
      }
      img.addEventListener("load", showImage);
      img.addEventListener("error", showFallback);
      if (img.complete) {
        if (img.naturalWidth > 0) fig.classList.remove("dashboard-preview--no-image");
        else showFallback();
      }
    });
  }

  document.querySelectorAll("[data-matrix]").forEach(function (el) {
    startMatrix(el);
  });
  document.querySelectorAll("[data-tilt]").forEach(wireTilt);
  wireDashboardPreview();
  initGsapAnimations();
})();
