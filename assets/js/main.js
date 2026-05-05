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

  document.querySelectorAll("[data-releases-link]").forEach(function (el) {
    el.setAttribute("href", releasesLatestUrl());
  });

  document.querySelectorAll("[data-github-repo-link]").forEach(function (el) {
    el.setAttribute("href", githubRepoUrl());
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
})();
