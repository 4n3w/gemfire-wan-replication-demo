import org.apache.geode.cache.Declarable;
import org.apache.geode.cache.execute.Function;
import org.apache.geode.cache.execute.FunctionContext;

public class TogglePoisonPillFunction implements Function<String>, Declarable {

    @Override
    public String getId() {
        return "toggle-poison-pill";
    }

    @Override
    public void execute(FunctionContext<String> context) {
        String arg = context.getArguments();
        boolean enable = "true".equalsIgnoreCase(arg);
        PoisonPillCacheWriter.enabled.set(enable);
        context.getResultSender().lastResult("enabled=" + enable);
    }

    @Override
    public boolean isHA() {
        return false;
    }

    @Override
    public boolean hasResult() {
        return true;
    }
}
