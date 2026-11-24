/// JavaScript the app adds to every page.
enum AppScripts {
    /// The name the page uses to tell the app about playback: `{playing: true|false}`.
    static let mediaHandler = "mtvMedia"

    /// Runs in the page and in embedded players (all frames), at document start.
    ///
    /// - App feel: no text selection (except in text fields), no long-press menus,
    ///   no grey flash on tap.
    /// - Tells the app when a video starts or stops, so the screen stays on while
    ///   one plays.
    /// - Lock screen / Control Center: if the site doesn't name what's playing,
    ///   names it MTV Rewind (with the video's title when it has one).
    /// - `window.__mtvPiP(true)` puts the playing video in Picture in Picture,
    ///   `window.__mtvPiP(false)` brings it back. The app calls these when you
    ///   leave and come back.
    static let page = #"""
        (function () {
          if (window.__mtvLoaded) return;
          window.__mtvLoaded = true;

          // No fullscreen from the page or YouTube: iOS's fullscreen video window covered
          // the app. The app has its own Full button and landscape mode.
          function blocked() { return Promise.reject(new Error('Fullscreen is handled by the app')); }
          function noop() {}
          try {
            Element.prototype.requestFullscreen = blocked;
            Element.prototype.webkitRequestFullscreen = noop;
            Element.prototype.webkitRequestFullScreen = noop;
            HTMLVideoElement.prototype.webkitEnterFullscreen = noop;
            HTMLVideoElement.prototype.webkitEnterFullScreen = noop;
          } catch (e) {}

          var css =
            '*{-webkit-touch-callout:none;-webkit-user-select:none;user-select:none;' +
            '-webkit-tap-highlight-color:transparent}' +
            'input,textarea,[contenteditable],[contenteditable] *{' +
            '-webkit-user-select:text;user-select:text;-webkit-touch-callout:default}';
          function addStyle() {
            var style = document.createElement('style');
            style.setAttribute('data-mtv', '');
            style.textContent = css;
            (document.head || document.documentElement).appendChild(style);
          }
          if (document.documentElement) addStyle();
          else document.addEventListener('DOMContentLoaded', addStyle);

          function post(message) {
            try { window.webkit.messageHandlers.mtvMedia.postMessage(message); } catch (e) {}
          }
          function media() {
            return Array.prototype.slice.call(document.querySelectorAll('video, audio'));
          }
          function playingVideo() {
            var list = media();
            for (var i = 0; i < list.length; i++) {
              var m = list[i];
              if (!m.paused && !m.ended) return m;
            }
            return null;
          }

          var ourMetadata = null;
          function nameIt(m) {
            var session = navigator.mediaSession;
            if (!session || typeof MediaMetadata === 'undefined') return;
            // The site named it itself: leave it alone.
            if (session.metadata && session.metadata !== ourMetadata) return;
            var title = (m.getAttribute('title') || m.getAttribute('aria-label') || '').trim();
            // Inside the YouTube player the page title is the video's ("Artist - Song - YouTube").
            if (!title && window.top !== window) {
              title = (document.title || '').replace(/\s*-\s*YouTube\s*$/, '').trim();
            }
            title = title || 'MTV Rewind';
            if (ourMetadata && ourMetadata.title === title) return;
            ourMetadata = new MediaMetadata({
              title: title,
              artist: 'MTV Rewind',
              album: 'Music videos, 24/7'
            });
            session.metadata = ourMetadata;
          }

          var last = null;
          function report() {
            var m = playingVideo();
            var playing = !!m;
            if (playing !== last) {
              last = playing;
              post({ playing: playing });
            }
            if (m) nameIt(m);
          }
          // Media events don't bubble, so listen in the capture phase.
          ['playing', 'play', 'pause', 'ended', 'emptied'].forEach(function (type) {
            document.addEventListener(type, function () { setTimeout(report, 0); }, true);
          });

          window.__mtvPiP = function (enter) {
            if (enter) {
              var m = playingVideo();
              if (!m || m.tagName !== 'VIDEO' || m.disablePictureInPicture) return false;
              if (!m.webkitSupportsPresentationMode || !m.webkitSupportsPresentationMode('picture-in-picture')) return false;
              if (m.webkitPresentationMode !== 'inline') return false;
              m.webkitSetPresentationMode('picture-in-picture');
              return true;
            }
            media().forEach(function (m) {
              if (m.webkitPresentationMode && m.webkitPresentationMode !== 'inline') m.webkitSetPresentationMode('inline');
            });
            return true;
          };
        })();
        """#

    /// Main page only, at document start: no pinch zoom, like an app.
    static let noZoom = #"""
        (function () {
          var WANT = 'width=device-width, initial-scale=1, maximum-scale=1, user-scalable=no';
          function patch(meta) {
            if (meta.getAttribute('content') !== WANT) meta.setAttribute('content', WANT);
          }
          function isViewport(node) {
            return node.nodeName === 'META' && (node.getAttribute('name') || '').toLowerCase() === 'viewport';
          }
          new MutationObserver(function (mutations) {
            mutations.forEach(function (m) {
              if (m.type === 'attributes') { if (isViewport(m.target)) patch(m.target); return; }
              m.addedNodes.forEach(function (node) {
                if (isViewport(node)) patch(node);
                else if (node.querySelectorAll) node.querySelectorAll('meta[name="viewport"]').forEach(patch);
              });
            });
          }).observe(document, { childList: true, subtree: true, attributes: true, attributeFilter: ['content'] });
          document.addEventListener('DOMContentLoaded', function () {
            var metas = document.querySelectorAll('meta[name="viewport"]');
            if (metas.length) { metas.forEach(patch); return; }
            var meta = document.createElement('meta');
            meta.name = 'viewport';
            meta.content = WANT;
            (document.head || document.documentElement).appendChild(meta);
          });
        })();
        """#

    /// The name the page uses to send what's playing: see `main`.
    static let stateHandler = "mtvState"

    /// Main page only, at document end. Turns the site into just the picture, and
    /// gives the app a small API on `window.__app`.
    ///
    /// - Hides everything but the YouTube player, which fills the web view. The
    ///   app draws its own now-playing card, remote and sheets.
    /// - Skips the welcome popups.
    /// - Every second, sends `{title, artist, channel, channelName, icon, playing,
    ///   videoId, saved}` when it changes.
    static let main = #"""
        (function () {
          if (window.__app) return;
          try { localStorage.setItem('mtvRewindWelcomeSeen', 'true'); } catch (e) {}

          var css =
            'html,body{background:#000!important;overflow:hidden!important;margin:0!important}' +
            'body *{visibility:hidden!important;pointer-events:none!important}' +
            '.player-stage,.container,.tv-col,.tv-frame,.tv-screen{transform:none!important;' +
            'filter:none!important;contain:none!important;perspective:none!important}' +
            '#player{visibility:visible!important;position:fixed!important;top:0!important;left:0!important;' +
            'right:0!important;bottom:0!important;width:100%!important;height:100%!important;' +
            'max-width:none!important;max-height:none!important;' +
            'margin:0!important;border:0!important;border-radius:0!important;z-index:2147483647!important}';
          var style = document.createElement('style');
          style.textContent = css;
          (document.head || document.documentElement).appendChild(style);
          window.scrollTo(0, 0);

          function post(message) {
            try { window.webkit.messageHandlers.mtvState.postMessage(message); } catch (e) {}
          }
          function yt() { try { return player && player.getVideoData ? player : null; } catch (e) { return null; } }
          function savedList() {
            try { return JSON.parse(localStorage.getItem('mtvRewindPlaylist') || '[]'); } catch (e) { return []; }
          }
          function idOf(url) { return ((url || '').split('v=')[1] || '').split('&')[0]; }
          function clean(t) {
            return (t || '')
              .replace(/\s*[\(\[](official\s+)?(music\s+)?(video|audio|hd|hq|remastered[^\)\]]*|lyrics?[^\)\]]*)[\)\]]/gi, '')
              .replace(/\s*-\s*VEVO$/i, '').replace(/VEVO\s*$/i, '').replace(/\s+-\s+Topic$/i, '')
              .replace(/\s+/g, ' ').trim();
          }

          var lastSent = '';
          function tick() {
            var p = yt();
            var data = null;
            try { data = p ? p.getVideoData() : null; } catch (e) {}
            var raw = clean(data && data.title);
            var author = clean(data && data.author);
            var artist = author, title = raw;
            var dash = raw.indexOf(' - ');
            if (dash > 0) { artist = raw.slice(0, dash).trim(); title = raw.slice(dash + 3).trim(); }
            var info = {};
            try { info = (window.CHANNEL_CONFIG && window.CHANNEL_CONFIG.info[currentChannel]) || {}; } catch (e) {}
            var playlistMode = false;
            try { playlistMode = isPlaylistMode; } catch (e) {}
            var videoId = (data && data.video_id) || '';
            var state = {
              title: title,
              artist: artist,
              channel: (function () { try { return currentChannel || ''; } catch (e) { return ''; } })(),
              channelName: playlistMode ? 'Your Saved Videos' : (info.name || ''),
              icon: playlistMode ? '📼' : (info.icon || '📺'),
              playing: !!(p && p.getPlayerState && p.getPlayerState() === 1),
              videoId: videoId,
              saved: !!videoId && savedList().some(function (item) {
                return idOf(typeof item === 'string' ? item : item.url) === videoId;
              })
            };
            var key = JSON.stringify(state);
            if (key !== lastSent) { lastSent = key; post(state); }
          }
          setInterval(tick, 1000);

          var searchIndex = null;
          window.__app = {
            next: function () { nextVideo(); },
            previous: function () { previousVideo(); },
            skip: function () { if (typeof skipDeadVideo === 'function') skipDeadVideo(); else nextVideo(); },
            playPause: function () {
              var p = yt(); if (!p) return;
              if (p.getPlayerState() === 1) p.pauseVideo(); else p.playVideo();
            },
            channel: function (key) {
              if (key === 'tommyboy' && typeof tuneTommyBoy === 'function') tuneTommyBoy('featured');
              else loadChannel(key);
            },
            year: function (y) { playYear(y); },
            years: function () { return Object.keys(window.TIME_MACHINE || {}).map(Number).sort(); },
            catalog: function () {
              var cfg = window.CHANNEL_CONFIG || { info: {}, sections: {} };
              var have = function (key) {
                if (key === 'thisday') return false;
                if (key === 'founders' || key === 'tommyboy') return !!cfg.info[key];
                try { return !!(allPlaylists[key] && allPlaylists[key].length); } catch (e) { return false; }
              };
              return Object.keys(cfg.sections || {}).map(function (id) {
                var sec = cfg.sections[id];
                return {
                  id: id,
                  name: (sec.name || id).replace(/^[^A-Za-z0-9]+/, '').trim(),
                  channels: (sec.channels || []).filter(have).map(function (key) {
                    var info = cfg.info[key] || {};
                    var count = 0;
                    try { count = (allPlaylists[key] || []).length; } catch (e) {}
                    return { key: key, name: info.name || key, icon: info.icon || '📺', count: count };
                  })
                };
              }).filter(function (sec) { return sec.channels.length; });
            },
            search: async function (query) {
              if (!searchIndex) {
                searchIndex = await (await fetch('search-index.json')).json();
              }
              var deacc = function (s) {
                return (s || '').toLowerCase().normalize('NFD').replace(/[̀-ͯ]/g, '').replace(/\./g, '');
              };
              var terms = deacc(query).split(/\s+/).filter(Boolean);
              if (!terms.length) return [];
              var out = [];
              for (var i = 0; i < searchIndex.length && out.length < 400; i++) {
                var e = searchIndex[i];
                var a = deacc(e.a), s = deacc(e.s || e.t);
                var hay = a + ' ' + s;
                if (!terms.every(function (t) { return hay.indexOf(t) !== -1; })) continue;
                var score = (a === terms.join(' ') ? 0 : a.indexOf(terms[0]) === 0 ? 1 : 2);
                out.push({ id: e.id, artist: e.a || '', title: e.s || e.t || '', score: score });
              }
              out.sort(function (x, y) { return x.score - y.score; });
              return out.slice(0, 60);
            },
            play: function (id) {
              try { stopPlaylist(); } catch (e) {}
              var p = yt(); if (p) p.loadVideoById(id);
            },
            save: function () {
              var url = getCurrentVideoUrl();
              if (!url) return false;
              var list = savedList();
              var i = list.findIndex(function (item) { return (typeof item === 'string' ? item : item.url) === url; });
              if (i !== -1) { removeFromPlaylist(i); return false; }
              addToPlaylist(url);
              return true;
            },
            saved: function () {
              return savedList().map(function (item) {
                var url = typeof item === 'string' ? item : item.url;
                return { id: idOf(url), title: (typeof item === 'object' && item.title) || '' };
              });
            },
            playSaved: function (i) {
              var list = this.saved();
              if (list[i]) playVideoFromPlaylist(list[i].id, i);
            },
            playAll: function () { playAllPlaylist(); },
            remove: function (i) { removeFromPlaylist(i); },
            url: function () { return getCurrentVideoUrl(); },
            loudest: function () { try { updateVolume(100); } catch (e) {} }
          };
          setTimeout(function () { window.__app.loudest(); tick(); }, 2500);
        })();
        """#

}
