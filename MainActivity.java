package com.offlinepos.accounts;

import android.app.Activity;
import android.print.PrintManager;
import android.content.ContentResolver;
import android.content.ContentValues;
import android.content.Context;
import android.content.Intent;
import android.graphics.Color;
import android.net.Uri;
import android.os.Build;
import android.os.Bundle;
import android.os.Environment;
import android.provider.MediaStore;
import android.webkit.JavascriptInterface;
import android.webkit.ValueCallback;
import android.webkit.WebChromeClient;
import android.webkit.WebResourceRequest;
import android.webkit.WebResourceResponse;
import android.webkit.WebSettings;
import android.webkit.WebView;
import android.widget.Toast;

import androidx.webkit.WebViewAssetLoader;
import androidx.webkit.WebViewClientCompat;

import java.io.File;
import java.io.FileOutputStream;
import java.io.FileInputStream;
import java.io.InputStream;
import java.io.OutputStream;
import java.nio.charset.StandardCharsets;
import java.util.zip.ZipEntry;
import java.util.zip.ZipOutputStream;

public class MainActivity extends Activity {
    private static final int FILE_CHOOSER_REQUEST = 1001;
    private WebView webView;
    private ValueCallback<Uri[]> filePathCallback;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);

        getWindow().setStatusBarColor(Color.parseColor("#070A10"));
        getWindow().setNavigationBarColor(Color.parseColor("#070A10"));
        setTitle("Offline POS & Accounts Pro");

        webView = new WebView(this);
        setContentView(webView);

        WebSettings settings = webView.getSettings();
        settings.setJavaScriptEnabled(true);
        settings.setDomStorageEnabled(true);
        settings.setDatabaseEnabled(true);
        settings.setAllowFileAccess(false);
        settings.setAllowContentAccess(false);
        settings.setBuiltInZoomControls(false);
        settings.setDisplayZoomControls(false);
        settings.setSupportZoom(false);
        settings.setLoadWithOverviewMode(true);
        settings.setUseWideViewPort(false);

        final WebViewAssetLoader assetLoader = new WebViewAssetLoader.Builder()
                .addPathHandler("/assets/", new WebViewAssetLoader.AssetsPathHandler(this))
                .build();

        webView.setWebViewClient(new WebViewClientCompat() {
            @Override
            public WebResourceResponse shouldInterceptRequest(WebView view, WebResourceRequest request) {
                return assetLoader.shouldInterceptRequest(request.getUrl());
            }

            @SuppressWarnings("deprecation")
            @Override
            public WebResourceResponse shouldInterceptRequest(WebView view, String url) {
                return assetLoader.shouldInterceptRequest(Uri.parse(url));
            }
        });

        webView.addJavascriptInterface(new AndroidBridge(this), "AndroidBridge");

        webView.setWebChromeClient(new WebChromeClient() {
            @Override
            public boolean onShowFileChooser(WebView webView,
                                             ValueCallback<Uri[]> filePathCallback,
                                             FileChooserParams fileChooserParams) {
                if (MainActivity.this.filePathCallback != null) {
                    MainActivity.this.filePathCallback.onReceiveValue(null);
                }
                MainActivity.this.filePathCallback = filePathCallback;

                Intent intent = new Intent(Intent.ACTION_OPEN_DOCUMENT);
                intent.addCategory(Intent.CATEGORY_OPENABLE);
                intent.setType("application/json");
                intent.putExtra(Intent.EXTRA_MIME_TYPES, new String[]{"application/json", "text/json"});
                try {
                    startActivityForResult(intent, FILE_CHOOSER_REQUEST);
                    return true;
                } catch (Exception e) {
                    MainActivity.this.filePathCallback = null;
                    Toast.makeText(MainActivity.this, "File picker could not open.", Toast.LENGTH_LONG).show();
                    return false;
                }
            }
        });

        // Important: use an HTTPS-like appassets origin, not file://.
        webView.loadUrl("https://appassets.androidplatform.net/assets/index.html");
    }

    @Override
    protected void onActivityResult(int requestCode, int resultCode, Intent data) {
        super.onActivityResult(requestCode, resultCode, data);
        if (requestCode == FILE_CHOOSER_REQUEST) {
            Uri[] results = null;
            if (resultCode == Activity.RESULT_OK && data != null && data.getData() != null) {
                results = new Uri[]{data.getData()};
            }
            if (filePathCallback != null) {
                filePathCallback.onReceiveValue(results);
                filePathCallback = null;
            }
        }
    }

    @Override
    public void onBackPressed() {
        if (webView != null && webView.canGoBack()) {
            webView.goBack();
        } else {
            super.onBackPressed();
        }
    }

    public class AndroidBridge {
        private final Activity activity;

        AndroidBridge(Activity activity) {
            this.activity = activity;
        }

        @JavascriptInterface
        public void saveTextFile(String filename, String content, String mimeType) {
            activity.runOnUiThread(() -> {
                try {
                    String safeName = filename == null || filename.trim().isEmpty()
                            ? "OfflinePOS_Export.txt"
                            : filename.replaceAll("[\\\\/:*?\"<>|]", "_");
                    String type = mimeType == null || mimeType.trim().isEmpty() ? "text/plain" : mimeType;
                    OutputStream outputStream;
                    String message;

                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                        ContentResolver resolver = getContentResolver();
                        ContentValues values = new ContentValues();
                        values.put(MediaStore.Downloads.DISPLAY_NAME, safeName);
                        values.put(MediaStore.Downloads.MIME_TYPE, type);
                        values.put(MediaStore.Downloads.RELATIVE_PATH, Environment.DIRECTORY_DOWNLOADS + "/OfflinePOS");
                        values.put(MediaStore.Downloads.IS_PENDING, 1);

                        Uri collection = MediaStore.Downloads.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY);
                        Uri item = resolver.insert(collection, values);
                        if (item == null) throw new IllegalStateException("Could not create download file.");
                        outputStream = resolver.openOutputStream(item);
                        if (outputStream == null) throw new IllegalStateException("Could not open download file.");
                        outputStream.write(content.getBytes(StandardCharsets.UTF_8));
                        outputStream.flush();
                        outputStream.close();

                        values.clear();
                        values.put(MediaStore.Downloads.IS_PENDING, 0);
                        resolver.update(item, values, null, null);
                        message = "Saved to Downloads/OfflinePOS/" + safeName;
                    } else {
                        File base = new File(getExternalFilesDir(Environment.DIRECTORY_DOWNLOADS), "OfflinePOS");
                        if (!base.exists() && !base.mkdirs()) {
                            throw new IllegalStateException("Could not create export folder.");
                        }
                        File file = new File(base, safeName);
                        outputStream = new FileOutputStream(file);
                        outputStream.write(content.getBytes(StandardCharsets.UTF_8));
                        outputStream.flush();
                        outputStream.close();
                        message = "Saved: " + file.getAbsolutePath();
                    }
                    Toast.makeText(activity, message, Toast.LENGTH_LONG).show();
                } catch (Exception e) {
                    Toast.makeText(activity, "Save failed: " + e.getMessage(), Toast.LENGTH_LONG).show();
                }
            });
        }

        @JavascriptInterface
        public void saveEmergencyPack(String filename, String backupJson, String instructions) {
            activity.runOnUiThread(() -> {
                try {
                    String safeName = (filename == null || filename.trim().isEmpty())
                            ? "OfflinePOS_EMERGENCY_PACK.zip"
                            : filename.replaceAll("[\\/:*?\"<>|]", "_");
                    if (!safeName.toLowerCase().endsWith(".zip")) safeName += ".zip";

                    OutputStream rawOutput;
                    String message;
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                        ContentResolver resolver = getContentResolver();
                        ContentValues values = new ContentValues();
                        values.put(MediaStore.Downloads.DISPLAY_NAME, safeName);
                        values.put(MediaStore.Downloads.MIME_TYPE, "application/zip");
                        values.put(MediaStore.Downloads.RELATIVE_PATH, Environment.DIRECTORY_DOWNLOADS + "/OfflinePOS");
                        values.put(MediaStore.Downloads.IS_PENDING, 1);
                        Uri collection = MediaStore.Downloads.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY);
                        Uri item = resolver.insert(collection, values);
                        if (item == null) throw new IllegalStateException("Could not create emergency ZIP.");
                        rawOutput = resolver.openOutputStream(item);
                        if (rawOutput == null) throw new IllegalStateException("Could not open emergency ZIP.");

                        writeEmergencyZip(rawOutput, backupJson, instructions);

                        values.clear();
                        values.put(MediaStore.Downloads.IS_PENDING, 0);
                        resolver.update(item, values, null, null);
                        message = "Emergency Pack saved to Downloads/OfflinePOS/" + safeName;
                    } else {
                        File base = new File(getExternalFilesDir(Environment.DIRECTORY_DOWNLOADS), "OfflinePOS");
                        if (!base.exists() && !base.mkdirs()) throw new IllegalStateException("Could not create export folder.");
                        File file = new File(base, safeName);
                        rawOutput = new FileOutputStream(file);
                        writeEmergencyZip(rawOutput, backupJson, instructions);
                        message = "Emergency Pack saved: " + file.getAbsolutePath();
                    }
                    Toast.makeText(activity, message, Toast.LENGTH_LONG).show();
                } catch (Exception e) {
                    Toast.makeText(activity, "Emergency Pack failed: " + e.getMessage(), Toast.LENGTH_LONG).show();
                }
            });
        }

        private void writeEmergencyZip(OutputStream rawOutput, String backupJson, String instructions) throws Exception {
            try (ZipOutputStream zos = new ZipOutputStream(rawOutput)) {
                // 1) Full POS + login-hash emergency JSON
                zos.putNextEntry(new ZipEntry("POS_EMERGENCY_FULL_BACKUP.json"));
                zos.write((backupJson == null ? "{}" : backupJson).getBytes(StandardCharsets.UTF_8));
                zos.closeEntry();

                // 2) Human-readable recovery instructions
                zos.putNextEntry(new ZipEntry("RECOVERY_INSTRUCTIONS.txt"));
                zos.write((instructions == null ? "Offline POS Emergency Recovery Pack" : instructions).getBytes(StandardCharsets.UTF_8));
                zos.closeEntry();

                // 3) Current installed APK, so the app can be reinstalled even after deletion.
                String apkPath = getApplicationInfo().sourceDir;
                try (InputStream in = new FileInputStream(apkPath)) {
                    zos.putNextEntry(new ZipEntry("OfflinePOS_App.apk"));
                    byte[] buffer = new byte[8192];
                    int count;
                    while ((count = in.read(buffer)) != -1) zos.write(buffer, 0, count);
                    zos.closeEntry();
                }

                // 4) Small app/repository reference file
                String info = "Offline POS & Accounts Pro\\nVersion: 7.9\\nGitHub: https://github.com/faisashahfaisa22-eng/OfflinePOS\\n";
                zos.putNextEntry(new ZipEntry("APP_AND_GITHUB_INFO.txt"));
                zos.write(info.getBytes(StandardCharsets.UTF_8));
                zos.closeEntry();
            }
        }

        @JavascriptInterface
        public void printPage() {
            activity.runOnUiThread(() -> {
                try {
                    PrintManager printManager = (PrintManager) getSystemService(Context.PRINT_SERVICE);
                    String jobName = "Offline POS Report";
                    printManager.print(jobName, webView.createPrintDocumentAdapter(jobName), null);
                } catch (Exception e) {
                    Toast.makeText(activity, "Print could not start: " + e.getMessage(), Toast.LENGTH_LONG).show();
                }
            });
        }
    }
}
