import java.util.concurrent.atomic.AtomicBoolean;
import org.apache.geode.cache.CacheWriter;
import org.apache.geode.cache.CacheWriterException;
import org.apache.geode.cache.EntryEvent;
import org.apache.geode.cache.RegionEvent;

public class PoisonPillCacheWriter implements CacheWriter<String, Object> {

    public static final AtomicBoolean enabled = new AtomicBoolean(false);

    @Override
    public void beforeCreate(EntryEvent<String, Object> event) throws CacheWriterException {
        reject(event);
    }

    @Override
    public void beforeUpdate(EntryEvent<String, Object> event) throws CacheWriterException {
        reject(event);
    }

    @Override
    public void beforeDestroy(EntryEvent<String, Object> event) throws CacheWriterException {}

    @Override
    public void beforeRegionDestroy(RegionEvent<String, Object> event) throws CacheWriterException {}

    @Override
    public void beforeRegionClear(RegionEvent<String, Object> event) throws CacheWriterException {}

    @Override
    public void close() {}

    private void reject(EntryEvent<String, Object> event) throws CacheWriterException {
        if (!enabled.get()) return;
        Object val = event.getNewValue();
        if (val != null && val.toString().contains("Widget-5")) {
            throw new CacheWriterException(
                "Poison pill: rejecting Widget-5 order (key=" + event.getKey() + ")");
        }
    }
}
