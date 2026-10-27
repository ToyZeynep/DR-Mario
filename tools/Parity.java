import com.rummuscan.core.*;
import com.rummuscan.core.ai.*;
import java.util.Random;

public class Parity {
    static String boardStr(Board b) {
        StringBuilder sb = new StringBuilder();
        for (int r = 0; r < b.getHeight(); r++) for (int c = 0; c < b.getWidth(); c++) {
            Cell cell = b.getCell(c, r);
            sb.append(cell.toString());
            sb.append(cell.link == null ? '-' : (char)('0' + cell.link.ordinal()));
        }
        return sb.toString();
    }
    public static void main(String[] a) {
        Random r = new Random(42);
        StringBuilder rs = new StringBuilder("rng");
        for (int i = 0; i < 20; i++) rs.append(' ').append(r.nextInt(7)).append(',').append(r.nextInt(8)).append(',').append(r.nextBoolean()).append(',').append(String.format("%.12f", r.nextDouble())).append(',').append(r.nextLong());
        System.out.println(rs);
        Difficulty[] ds = Difficulty.values();
        for (int seed = 1; seed <= 12; seed++) {
            Difficulty d = ds[seed % 3];
            long s = seed * 7919L - 3;
            GameEngine left = new GameEngine(s, 8 + seed * 3, 20 + seed % 3 * 5);
            GameEngine right = new GameEngine(s, 8 + seed * 3, 20 + seed % 3 * 5);
            AiController al = new AiController(left, d, s ^ 99);
            AiController ar = new AiController(right, ds[(seed + 1) % 3], s ^ 77);
            for (int t = 0; t < 6000; t++) {
                al.update(); ar.update();
                left.tick(); right.tick();
                GameEngine.GarbageAttack g1 = left.drainOutgoingGarbage();
                GameEngine.GarbageAttack g2 = right.drainOutgoingGarbage();
                if (g1.count > 0) { java.util.Arrays.sort(g1.colors); right.receiveGarbage(g1); }
                if (g2.count > 0) { java.util.Arrays.sort(g2.colors); left.receiveGarbage(g2); }
                if (t % 500 == 0 || left.getState() != GameState.RUNNING || right.getState() != GameState.RUNNING) {
                    System.out.println(seed + " " + t + " " + left.getState() + " " + left.getScore() + " " + left.getTickCount() + " " + boardStr(left.getBoard()).hashCode()
                        + " | " + right.getState() + " " + right.getScore() + " " + boardStr(right.getBoard()).hashCode());
                }
                if (VsOutcome.of(left.getState(), right.getState()).isDecided()) break;
            }
            System.out.println(seed + " final " + boardStr(left.getBoard()));
        }
    }
}
