import com.sun.net.httpserver.*;
import java.io.*;
import java.net.*;
import java.util.*;
import java.util.concurrent.atomic.*;
import org.apache.geode.cache.*;
import org.apache.geode.cache.client.*;

public class DataGenerator {
    static final AtomicBoolean running = new AtomicBoolean(false);
    static final AtomicInteger rateMs = new AtomicInteger(1000);
    static final AtomicInteger counter = new AtomicInteger(0);

    public static void main(String[] args) throws Exception {
        String locatorHost = env("LOCATOR_HOST", "site-a-locator");
        int locatorPort = Integer.parseInt(env("LOCATOR_PORT", "10335"));
        int httpPort = Integer.parseInt(env("HTTP_PORT", "8888"));

        System.out.println("Connecting to GemFire at " + locatorHost + ":" + locatorPort);
        ClientCache cache = new ClientCacheFactory()
            .addPoolLocator(locatorHost, locatorPort)
            .setPdxReadSerialized(true)
            .set("log-level", "warning")
            .create();

        Region<String, String> orders = cache
            .<String, String>createClientRegionFactory(ClientRegionShortcut.PROXY)
            .create("Orders");

        @SuppressWarnings("unchecked")
        Region<Object, Object> dlq = (Region<Object, Object>) (Region<?, ?>)
            cache.createClientRegionFactory(ClientRegionShortcut.PROXY)
            .create("GatewayFailedEvents");

        System.out.println("Connected. Starting HTTP control server on port " + httpPort);

        HttpServer server = HttpServer.create(new InetSocketAddress(httpPort), 0);

        server.createContext("/status", ex -> {
            json(ex, "{\"running\":" + running.get()
                + ",\"rateMs\":" + rateMs.get()
                + ",\"counter\":" + counter.get() + "}");
        });

        server.createContext("/start", ex -> {
            if (!running.get()) {
                running.set(true);
                Thread t = new Thread(() -> generate(orders));
                t.setDaemon(true);
                t.start();
            }
            json(ex, "{\"running\":true,\"rateMs\":" + rateMs.get() + "}");
        });

        server.createContext("/stop", ex -> {
            running.set(false);
            json(ex, "{\"running\":false}");
        });

        server.createContext("/rate", ex -> {
            String q = ex.getRequestURI().getQuery();
            if (q != null && q.startsWith("ms=")) {
                try { rateMs.set(Integer.parseInt(q.substring(3))); }
                catch (NumberFormatException ignored) {}
            }
            json(ex, "{\"rateMs\":" + rateMs.get() + "}");
        });

        server.createContext("/dlq/clear", ex -> {
            try {
                Set<Object> keys = dlq.keySetOnServer();
                int count = keys.size();
                if (count > 0) dlq.removeAll(keys);
                json(ex, "{\"cleared\":" + count + "}");
            } catch (Exception e) {
                json(ex, "{\"error\":\"" + e.getMessage().replace("\"", "'") + "\"}");
            }
        });

        server.createContext("/dlq", ex -> {
            try {
                Set<Object> allKeys = dlq.keySetOnServer();
                int total = allKeys.size();
                List<Object> keys = new ArrayList<>(allKeys);
                if (keys.size() > 50) keys = keys.subList(keys.size() - 50, keys.size());
                Map<Object, Object> entries = dlq.getAll(keys);
                StringBuilder sb = new StringBuilder();
                sb.append("{\"count\":").append(total).append(",\"entries\":[");
                boolean first = true;
                for (Object k : keys) {
                    Object v = entries.get(k);
                    if (!first) sb.append(",");
                    first = false;
                    String vs = v != null ? String.valueOf(v) : "";
                    /* Extract fields from FailedEventRegionValue toString */
                    String orderKey = extract(vs, "key=");
                    String failedTime = extract(vs, "failedTime=");
                    String exception = extract(vs, "exception=");
                    /* Extract embedded JSON value */
                    String embeddedValue = "null";
                    int vi = vs.indexOf("value={");
                    if (vi >= 0) {
                        int depth = 0;
                        int start = vi + 6;
                        for (int i = start; i < vs.length(); i++) {
                            char c = vs.charAt(i);
                            if (c == '{') depth++;
                            else if (c == '}') { depth--; if (depth == 0) { embeddedValue = vs.substring(start, i + 1); break; } }
                        }
                    }
                    sb.append("{\"key\":\"").append(jsonEsc(orderKey)).append("\"");
                    sb.append(",\"value\":").append(embeddedValue);
                    sb.append(",\"failedTime\":\"").append(jsonEsc(failedTime)).append("\"");
                    sb.append(",\"exception\":\"").append(jsonEsc(exception)).append("\"");
                    sb.append("}");
                }
                sb.append("]}");
                json(ex, sb.toString());
            } catch (Exception e) {
                json(ex, "{\"count\":0,\"entries\":[],\"error\":\"" + e.getMessage().replace("\"", "'") + "\"}");
            }
        });

        server.setExecutor(null);
        server.start();

        /* Auto-start */
        if ("true".equalsIgnoreCase(env("AUTO_START", "true"))) {
            running.set(true);
            Thread t = new Thread(() -> generate(orders));
            t.setDaemon(true);
            t.start();
        }

        Thread.currentThread().join();
    }

    static void generate(Region<String, String> orders) {
        System.out.println("Generation started at " + rateMs.get() + "ms interval");
        while (running.get()) {
            try {
                int c = counter.incrementAndGet();
                String key = "order-" + c;
                int widget = (c % 5) + 1;
                String ts = java.time.Instant.now().toString();
                String val = "{\"id\":\"" + key
                    + "\",\"product\":\"Widget-" + widget
                    + "\",\"quantity\":" + c
                    + ",\"timestamp\":\"" + ts + "\"}";
                orders.put(key, val);
                Thread.sleep(rateMs.get());
            } catch (InterruptedException e) {
                break;
            } catch (Exception e) {
                System.err.println("Put failed: " + e.getMessage());
                try { Thread.sleep(2000); } catch (InterruptedException ie) { break; }
            }
        }
        System.out.println("Generation stopped");
    }

    static void json(HttpExchange ex, String body) throws IOException {
        ex.getResponseHeaders().set("Content-Type", "application/json");
        byte[] b = body.getBytes();
        ex.sendResponseHeaders(200, b.length);
        ex.getResponseBody().write(b);
        ex.getResponseBody().close();
    }

    static String env(String key, String def) {
        String v = System.getenv(key);
        return v != null ? v : def;
    }

    /** Extract a "field=value" from the FailedEventRegionValue toString, delimited by "; " */
    static String extract(String s, String field) {
        int i = s.indexOf(field);
        if (i < 0) return "";
        int start = i + field.length();
        int end = s.indexOf("; ", start);
        if (end < 0) {
            /* last field — strip trailing ) */
            end = s.length();
            String result = s.substring(start, end).trim();
            if (result.endsWith(")")) result = result.substring(0, result.length() - 1);
            return result;
        }
        return s.substring(start, end).trim();
    }

    static String jsonEsc(String s) {
        return s.replace("\\", "\\\\").replace("\"", "\\\"");
    }
}
