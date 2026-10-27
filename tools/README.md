# iOS ⇄ Android eşitleme notları

Bu iOS uygulaması, Hasan'ın Android oyunu **HasanDagasan/VirusHunt** (libGDX, Java) ile
birebir aynı oyundur. Kod Java'dan Swift'e **satır satır** çevrildi; dosya ve fonksiyon adları
aynı tutuldu ki Android'de bir şey değişince iOS'a taşımak kolay olsun.

**Son eşitlenen Android sürümü:** `dev` dalı, commit `bf3cd92` (2026-10-27) — sürüm 1.15 (19).

## Klasörler

| iOS (`DR. Mario/DR. Mario/`) | Android karşılığı |
|---|---|
| `Gdx/` | libGDX'in kendisi (Game/Screen, SpriteBatch, Viewport, Preferences, Net, Music). iOS'ta Metal + UIKit (`IOSBackend.swift`). |
| `core/` | `core/src/main/java/com/rummuscan/core` (Board, GameEngine, AI, net, i18n) |
| `game/` | `core/src/main/java/com/rummuscan/game` (tüm ekranlar) + `virushunt/VirusHuntGame` |
| `platform/` | `android/src/...` (reklam, geri bildirim, değerlendirme, başlatıcı) |
| `GameAssets/` | `assets/` (müzikler `.ogg` → `.m4a`) |

## Otomatik üretilen dosyalar (elle düzenleme)

```sh
# 24 dillik metinler (Txt.java, Lang.java, HelpText.java)
python3 tools/i18n.py <VirusHunt>/core/src/main/java/com/rummuscan/core/i18n "DR. Mario/DR. Mario/core/i18n"
# Piksel font glyph'leri (PixelFont.java)
python3 tools/font.py <VirusHunt>/core/src/main/java/com/rummuscan/game/PixelFont.java "DR. Mario/DR. Mario/game/PixelFontData.swift"
# Geri bildirim penceresi metinleri (android/res/values-*/strings.xml)
python3 tools/fbstrings.py <VirusHunt>/android/res "DR. Mario/DR. Mario/platform/FeedbackStrings.swift"
# Uygulama ikonu (tools/make_icon.ps1'in Python karşılığı)
python3 tools/make_icon.py <VirusHunt> "DR. Mario/DR. Mario/Assets.xcassets/AppIcon.appiconset/AppIcon.png"
# Müzikler
for f in <VirusHunt>/assets/music/*.ogg; do ffmpeg -y -i "$f" -c:a aac -b:a 128k "DR. Mario/DR. Mario/GameAssets/music/$(basename "${f%.ogg}").m4a"; done
```

## Online uyumluluk (iPhone ⇄ Android aynı maç)

Online VS'te iki cihaz aynı seed'le aynı virüs/hap dizisini üretmek zorunda. `Gdx/JavaRandom.swift`
`java.util.Random`'un birebir kopyasıdır. `tools/Parity.java` + `tools/ParityMain.swift`, Java ve
Swift motorlarını aynı tohumlarla CPU'ya karşı CPU oynatıp çıktıyı karşılaştırır — **birebir aynı
olmalı** (motorda/AI'da/rastgelelikte bir değişiklik taşındıysa yeniden çalıştırın):

```sh
javac -d out <VirusHunt>/core/src/main/java/com/rummuscan/core/{*,ai/*,i18n/*}.java tools/Parity.java && java -cp out Parity > java.txt
swiftc -O -o parity tools/ParityMain.swift "DR. Mario/DR. Mario"/Gdx/*.swift "DR. Mario/DR. Mario"/core/*.swift "DR. Mario/DR. Mario"/core/*/*.swift && ./parity > swift.txt
diff java.txt swift.txt && echo AYNI
```

`tools/SmokeMain.swift`: sahte sunucuyla tüm ekran akışını gezen çökme testi (Linux/macOS'ta çalışır).

## iOS'a özel farklar (bilerek)

- **Hesap:** Play Games yalnızca Android'de. iOS misafir hesapla girer (Android'deki
  masaüstü sürüm gibi); aynı sunucu, aynı lobi. App Store kuralı (2.3.10) gereği hesap seçim
  ekranında "PLAY GAMES" düğmesi iOS'ta gösterilmez. İleride Game Center eklenecekse sunucuya
  (`server/login.php`) yeni bir `kind` gerekir.
- **Reklam:** AdMob iOS reklam birimleri `platform/IOSPlatform.swift` → `AdConfig`; uygulama kimliği
  `Info.plist` → `GADApplicationIdentifier`. Boşken yayın derlemesinde reklam kapalıdır.
- **Analiz/geri bildirim:** aynı uç noktalar, `platform = "ios"`.

## GitHub'da otomatik iOS derlemesi (CI)

`tools/ci/ios-build.yml`: macOS üzerinde simülatör (Debug) ve cihaz (Release, imzasız) derlemesi yapar,
simülatörde 10 ekranın görüntüsünü alır (Türkçe + İngilizce başlık) ve `ios-build` adlı yapıt olarak
yükler. Repo herkese açık olduğu için GitHub Actions dakikaları ücretsiz.

Etkinleştirmek için dosyanın `.github/workflows/ios-build.yml` konumuna konması gerekir. GitHub bunu
yalnızca `workflow` izni olan bir oturumdan kabul eder:

- **Tarayıcıdan:** GitHub'da repo → *Add file → Create new file* → ad: `.github/workflows/ios-build.yml`
  → bu dosyanın içeriğini yapıştır → *Commit*.
- **Terminalden:** `gh auth refresh -h github.com -s workflow` ile izin ver, sonra dosyayı kopyalayıp gönder.

Sonra her `DR. Mario/` değişikliğinde kendiliğinden çalışır; elle başlatmak için repo → *Actions* →
*iOS build* → *Run workflow*. Sonuçlar: çalışmanın sayfasındaki *Artifacts → ios-build*
(`build.log`, `shots/*.png`).
