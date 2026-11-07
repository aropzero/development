package com.example.ironfrontline;

import android.annotation.SuppressLint;
import android.app.Activity;
import android.content.res.AssetFileDescriptor;
import android.net.Uri;
import android.os.Bundle;
import android.view.Window;
import android.view.WindowManager;
import android.webkit.MimeTypeMap;
import android.webkit.WebChromeClient;
import android.webkit.WebResourceRequest;
import android.webkit.WebResourceResponse;
import android.webkit.WebSettings;
import android.webkit.WebView;
import android.webkit.WebViewClient;

import java.io.IOException;
import java.io.InputStream;
import java.nio.charset.StandardCharsets;
import java.util.HashMap;
import java.util.Locale;
import java.util.Map;

/**
 * SIEGE: FALLEN GATE — Android wrapper.
 *
 * Hosts the 3D game from Android assets inside a single WebView. Assets are
 * served over a synthetic HTTPS origin (https://appassets.androidplatform.net/)
 * so that ES modules, import maps, audio samples and glTF models all load
 * correctly. No network permission and no external dependencies are required.
 */
public class MainActivity extends Activity {

    private static final String HOST = "appassets.androidplatform.net";
    private static final String BASE = "https://" + HOST + "/";
    private WebView web;

    @SuppressLint("SetJavaScriptEnabled")
    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);

        requestWindowFeature(Window.FEATURE_NO_TITLE);
        getWindow().addFlags(WindowManager.LayoutParams.FLAG_FULLSCREEN);

        web = new WebView(this);
        WebSettings s = web.getSettings();
        s.setJavaScriptEnabled(true);
        s.setDomStorageEnabled(true);
        s.setMediaPlaybackRequiresUserGesture(false);
        s.setUseWideViewPort(true);
        s.setLoadWithOverviewMode(true);
        s.setAllowFileAccess(false);
        s.setAllowContentAccess(false);
        s.setCacheMode(WebSettings.LOAD_NO_CACHE);
        // Everything is served from packaged assets via the interceptor. Block any
        // real network access so a missed asset fails fast instead of silently
        // hitting the internet (and never depends on the INTERNET permission).
        s.setBlockNetworkLoads(true);

        web.setWebViewClient(new WebViewClient() {
            @Override
            public WebResourceResponse shouldInterceptRequest(WebView view, WebResourceRequest request) {
                return serveFromAssets(request.getUrl());
            }
        });
        web.setWebChromeClient(new WebChromeClient());
        web.setBackgroundColor(0xFF12151C);
        web.loadUrl(BASE + "game3d/index.html");

        setContentView(web);
    }

    /** Map an intercepted URL (https://appassets.androidplatform.net/...) to an asset. */
    private WebResourceResponse serveFromAssets(Uri url) {
        if (url == null || !HOST.equalsIgnoreCase(url.getHost())) {
            return null;
        }
        String path = url.getPath();
        if (path == null || path.isEmpty() || path.equals("/")) {
            path = "/index.html";
        }
        // Uri.getPath() returns the decoded path, but stay defensive: decode any
        // leftover percent-encodings (e.g. %20 for spaces) without mangling '+'.
        if (path.indexOf('%') >= 0) {
            try {
                path = Uri.decode(path);
            } catch (Exception e) {
                // fall through with the raw path
            }
        }
        String assetPath = path.startsWith("/") ? path.substring(1) : path;

        InputStream is;
        try {
            is = getAssets().open(assetPath);
        } catch (IOException e) {
            return null;
        }

        // A well-formed response: explicit 200 status, CORS header (harmless for
        // same-origin but satisfies any fetch/bitmap checks), no-cache, and a
        // content length when the asset entry is file-backed.
        Map<String, String> headers = new HashMap<>();
        headers.put("Access-Control-Allow-Origin", "*");
        headers.put("Access-Control-Allow-Methods", "GET, HEAD, OPTIONS");
        headers.put("Access-Control-Allow-Headers", "*");
        headers.put("Cache-Control", "no-store, no-cache, must-revalidate");
        headers.put("Pragma", "no-cache");

        long length = -1;
        try {
            AssetFileDescriptor afd = getAssets().openFd(assetPath);
            if (afd != null) {
                length = afd.getLength();
                afd.close();
            }
        } catch (IOException e) {
            // stream assets (e.g. compressed media) have no file descriptor; skip length
        }
        if (length >= 0) {
            headers.put("Content-Length", String.valueOf(length));
        }

        String mime = mimeFor(assetPath);
        boolean isText = mime.startsWith("text/") || mime.equals("application/json");
        String encoding = isText ? "utf-8" : null;
        return new WebResourceResponse(mime, encoding, 200, "OK", headers, is);
    }

    private String mimeFor(String path) {
        String ext = MimeTypeMap.getFileExtensionFromUrl(path.toLowerCase(Locale.ROOT));
        String mime = MimeTypeMap.getSingleton().getMimeTypeFromExtension(ext);
        if (mime != null) {
            // Ensure ES modules are served with a JS MIME type.
            if (mime.startsWith("text/")) {
                return mime;
            }
            return mime;
        }
        switch (ext) {
            case "html": return "text/html";
            case "js": case "mjs": return "text/javascript";
            case "css": return "text/css";
            case "json": return "application/json";
            case "glb": return "model/gltf-binary";
            case "ogg": return "audio/ogg";
            case "wav": return "audio/wav";
            case "png": return "image/png";
            case "jpg": case "jpeg": return "image/jpeg";
            case "webp": return "image/webp";
            case "svg": return "image/svg+xml";
            default: return "application/octet-stream";
        }
    }

    @Override
    protected void onDestroy() {
        if (web != null) {
            web.destroy();
        }
        super.onDestroy();
    }
}
