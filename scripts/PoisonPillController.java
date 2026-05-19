import com.sun.net.httpserver.*;
import java.io.*;
import java.net.*;
import java.util.*;
import org.apache.geode.cache.client.*;
import org.apache.geode.cache.execute.*;

public class PoisonPillController {

    static boolean lastKnownState = false;

    public static void main(String[] args) throws Exception {
        String locatorHost = env("LOCATOR_HOST", "site-b-locator");
        int locatorPort = Integer.parseInt(env("LOCATOR_PORT", "10335"));
        int httpPort = Integer.parseInt(env("HTTP_PORT", "8889"));

        System.out.println("Connecting to GemFire at " + locatorHost + ":" + locatorPort);
        ClientCache cache = new ClientCacheFactory()
            .addPoolLocator(locatorHost, locatorPort)
            .setPdxReadSerialized(true)
            .set("log-level", "warning")
            .create();

        // Need a pool reference to execute functions on servers
        System.out.println("Connected. Starting HTTP control server on port " + httpPort);

        HttpServer server = HttpServer.create(new InetSocketAddress(httpPort), 0);

        server.createContext("/status", ex -> {
            json(ex, "{\"poisonPill\":" + lastKnownState + "}");
        });

        server.createContext("/enable", ex -> {
            String result = executeToggle(cache, "true");
            lastKnownState = true;
            json(ex, "{\"poisonPill\":true,\"result\":\"" + escape(result) + "\"}");
        });

        server.createContext("/disable", ex -> {
            String result = executeToggle(cache, "false");
            lastKnownState = false;
            json(ex, "{\"poisonPill\":false,\"result\":\"" + escape(result) + "\"}");
        });

        server.setExecutor(null);
        server.start();
        System.out.println("Poison pill controller listening on port " + httpPort);

        Thread.currentThread().join();
    }

    static String executeToggle(ClientCache cache, String arg) {
        try {
            @SuppressWarnings("unchecked")
            ResultCollector<String, List<String>> rc = FunctionService
                .onServers(cache.getDefaultPool())
                .setArguments(arg)
                .execute("toggle-poison-pill");
            List<String> results = rc.getResult();
            return results.isEmpty() ? "no-result" : results.get(0);
        } catch (Exception e) {
            System.err.println("Function execution failed: " + e.getMessage());
            return "error: " + e.getMessage();
        }
    }

    static void json(HttpExchange ex, String body) throws IOException {
        ex.getResponseHeaders().set("Content-Type", "application/json");
        byte[] b = body.getBytes();
        ex.sendResponseHeaders(200, b.length);
        ex.getResponseBody().write(b);
        ex.getResponseBody().close();
    }

    static String escape(String s) {
        return s.replace("\\", "\\\\").replace("\"", "\\\"");
    }

    static String env(String key, String def) {
        String v = System.getenv(key);
        return v != null ? v : def;
    }
}
