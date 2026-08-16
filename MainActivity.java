package com.offlinepos.accounts;

import android.app.Activity;
import android.app.PrintManager;
import android.content.ContentResolver;
import android.content.ContentValues;
import android.content.Context;
import android.content.Intent;
import android.net.Uri;
import android.os.Build;
import android.os.Bundle;
import android.os.Environment;
import android.provider.MediaStore;
import android.webkit.JavascriptInterface;
import android.webkit.ValueCallback;
import android.webkit.WebChromeClient;
import android.webkit.WebSettings;
import android.webkit.WebView;
import android.webkit.WebViewClient;
import android.widget.Toast;

import java.io.File;
import java.io.FileOutputStream;
import java.io.OutputStream;
import java.nio.charset.StandardCharsets;

public class MainActivity extends Activity {
    private static final int FILE_CHOOSER_REQUEST = 1001;
    private WebView webView;
    private ValueCallback<Uri[]> filePathCallback;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);

        webView = new WebView(this);
        setContentView(webView);

        WebSettings settings = webView.getSettings();
        settings.setJavaScriptEnabled(true);
        settings.setDomStorageEnabled(true);
        settings.setDatabaseEnabled(true);
        settings.setAllowFileAccess(true);
        settings.setAllowContentAccess(true);
        settings.setBuiltInZoomControls(false);
        settings.setDisplayZoomControls(false);
        settings.setSupportZoom(false);
        settings.setLoadWithOverviewMode(true);
        settings.setUseWideViewPort(false);

        webView.setWebViewClient(new WebViewClient());
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
                intent.putExtra(Intent.EXTRA_MIME_TYPES, new String[]{"application/json", "text/json", "*/*"});
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

        webView.loadUrl("file:///android_asset/index.html");
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
