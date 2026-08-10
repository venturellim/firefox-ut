// Firefox defaults for Ubuntu Touch / Lomiri on the Volla Phone Plinius.
//
// Installed as gecko/defaults/pref/ut-defaults.js, alongside the stock
// channel-prefs.js. These are *defaults*: anything here can still be changed
// from about:config, and nothing is written back into the read-only click
// payload.
//
// Device: 1080x2400 DSI panel, Mali GPU behind libhybris, no VA-API, no X11.

// --- Scale -----------------------------------------------------------------
// Mir reports scale 1 for this panel, so unscaled Firefox chrome renders at
// roughly a third of a usable size. 2.0 gives 540 CSS px across the 1080px
// panel and was checked on device.
pref("layout.css.devPixelsPerPx", "2.0");
pref("browser.uidensity", 1); // 1 = touch: taller toolbars and tab strip

// --- Identify as a mobile browser ------------------------------------------
// Without this Firefox announces itself as desktop Linux, so Google and
// Wikipedia serve desktop layouts -- unusable on a phone, and the reason
// Wikipedia never offers its mobile site. Gecko builds the desktop UA from the
// platform, so it has to be overridden wholesale.
//
// Keep the rv/Firefox version roughly in step with the Gecko this ships with;
// it is a literal string and will not update itself.
pref("general.useragent.override",
     "Mozilla/5.0 (Android 14; Mobile; rv:155.0) Gecko/155.0 Firefox/155.0");

// Honour <meta name="viewport">, without which a mobile layout still gets laid
// out at desktop width.
pref("dom.meta-viewport.enabled", true);

// --- Touch input -----------------------------------------------------------
pref("dom.w3c_touch_events.enabled", 1); // 1 = always on; 2 = autodetect, which
                                         // guesses wrong without an X touch device
pref("apz.allow_zooming", true);              // pinch to zoom
pref("apz.allow_double_tap_zooming", true);   // double tap to zoom
pref("browser.ui.zoom.force-user-scalable", true); // ignore user-scalable=no
pref("general.smoothScroll", true);

// Panning has to win over tap on a touchscreen, or short drags are swallowed as
// clicks and the page feels stuck.
pref("apz.touch_start_tolerance", "0.1");

// --- Chrome layout ---------------------------------------------------------
// Vertical space is the scarcest resource on a 2400px-tall phone held in one
// hand; claw back the title bar and the bookmarks toolbar.
pref("browser.tabs.inTitlebar", 1);
pref("browser.toolbars.bookmarks.visibility", "never");

// --- Updates ---------------------------------------------------------------
// The click payload is mounted read-only, so the updater can only ever fail
// noisily. Updates come from rebuilding and reinstalling the click.
pref("app.update.auto", false);
pref("app.update.service.enabled", false);
pref("browser.shell.checkDefaultBrowser", false);

// --- Graphics --------------------------------------------------------------
// Hardware decode goes through libhybris here; there is no VA-API driver, and
// probing for one costs startup time and log noise.
pref("media.ffmpeg.vaapi.enabled", false);
pref("media.hardware-video-decoding.enabled", false);

// Hardware rendering works here. The startup segfault that first looked like an
// EGL failure was Gecko painting a modal profile-error dialog, and it went away
// with the profile fix. Software WebRender is actively worse on this device --
// it logs "RenderCompositorSWGL failed mapping default framebuffer" -- so leave
// gfx.webrender.software at its default.

// --- Misc ------------------------------------------------------------------
pref("browser.aboutwelcome.enabled", false); // no room for the onboarding tour
pref("datareporting.policy.firstRunURL", "");
