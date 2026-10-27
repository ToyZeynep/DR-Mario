//
//  Txt.swift
//  DR. Mario
//
//  OTOMATİK ÜRETİLDİ (tools/i18n.py): com.rummuscan.core.i18n.Txt + Lang (VirusHunt).
//  Elle düzenleme; Android tarafındaki Txt.java değişince betiği yeniden çalıştır.
//

import Foundation

/// Oyun dili: cihazın dili desteklenenlerden biriyse o, aksi hâlde İngilizce.
enum Lang: Int, CaseIterable {
    case EN, TR, DE, ES, FR, PT, ID, RU, IT, PL, NL, UK, RO, CS, HU, SV, FI, DA, MS, FIL, EL, SK, NB, VI

    var code: String {
        switch self {
        case .EN: return "en"
        case .TR: return "tr"
        case .DE: return "de"
        case .ES: return "es"
        case .FR: return "fr"
        case .PT: return "pt"
        case .ID: return "id"
        case .RU: return "ru"
        case .IT: return "it"
        case .PL: return "pl"
        case .NL: return "nl"
        case .UK: return "uk"
        case .RO: return "ro"
        case .CS: return "cs"
        case .HU: return "hu"
        case .SV: return "sv"
        case .FI: return "fi"
        case .DA: return "da"
        case .MS: return "ms"
        case .FIL: return "fil"
        case .EL: return "el"
        case .SK: return "sk"
        case .NB: return "nb"
        case .VI: return "vi"
        }
    }

    var ordinal: Int { return rawValue }

    private static var currentLang = Lang.EN

    static func current() -> Lang { return currentLang }

    static func set(_ lang: Lang?) { currentLang = lang ?? .EN }

    /// Cihaz dilinden seçer; desteklenmeyen diller İngilizceye düşer.
    static func detect() -> Lang {
        let code = Locale.preferredLanguages.first.map { String($0.split(separator: "-").first ?? "") }
        return fromCode(code)
    }

    static func fromCode(_ code: String?) -> Lang {
        guard let code = code else { return .EN }
        var c = code.lowercased()
        if c == "in" { c = "id" }
        if c == "tl" { c = "fil" }
        if c == "no" || c == "nn" { c = "nb" }
        for l in Lang.allCases where l.code == c { return l }
        return .EN
    }
}

/// Oyundaki TÜM kullanıcı metinleri, 24 dilde (Lang sırasıyla). Ekranlar Txt.X.s() ile o anki dilin metnini alır.
enum Txt: Int, CaseIterable {
    case TITLE_MAIN
    case TITLE_SUB
    case MENU_SINGLE
    case MENU_ONLINE
    case MENU_CPU
    case MENU_ACCOUNT
    case FEEDBACK
    case COMING_SOON
    case SET_TITLE_SINGLE
    case SET_TITLE_ONLINE
    case SET_TITLE_CPU
    case VIRUS_LEVEL
    case SPEED
    case MUSIC_TYPE
    case CPU_LEVEL
    case START
    case BACK
    case SPEED_LOW
    case SPEED_MED
    case SPEED_HI
    case DIFF_EASY
    case DIFF_MED
    case DIFF_HARD
    case MUSIC_OFF
    case HUD_SPEED
    case HUD_SPEED_LOW
    case HUD_SPEED_MED
    case HUD_SPEED_HI
    case TOP
    case SCORE
    case LEVEL
    case VIRUS
    case PAUSED
    case RESUME
    case AD_PRIVACY
    case AD_UNAVAILABLE
    case AD_CONTINUE
    case MENU
    case STAGE_CLEAR
    case GAME_OVER
    case PRESS_START
    case YOU
    case CPU
    case RIVAL
    case VS
    case YOU_WIN
    case YOU_LOSE
    case DRAW
    case RIVAL_LEFT
    case CONNECTION_LOST
    case SIGNING_IN
    case CONNECTING
    case ACCOUNT_PREFIX
    case RETRY
    case SIGN_IN_FAILED
    case ERROR
    case NETWORK_ERROR
    case SERVER_UNAVAILABLE
    case WINS
    case LOSSES
    case REFRESH
    case HOW_TO_PLAY
    case PRIVACY_POLICY
    case WORLD_NO
    case UNRANKED
    case NEXT_RANK
    case TOP_RANK
    case PLAY_GAMES
    case GUEST
    case LV
    case PLAYERS_ONLINE
    case NOBODY_HERE
    case TRY_QUICK_MATCH
    case INVITED
    case IN_MATCH
    case PLAYER_BUSY
    case SEARCHING
    case QUICK_MATCH
    case CANCEL_INVITE
    case LEADERBOARD
    case ACCEPT
    case DECLINE
    case INVITES_YOU
    case INVITED_TOAST
    case CANCEL_FIRST
    case INVITE_FAILED
    case FAILED
    case STATUS_DECLINED
    case STATUS_EXPIRED
    case STATUS_CANCELLED
    case STATUS_ACCEPTED
    case OK_BTN
    case INVITE_SENT
    case WAITING_REPLY
    case NEW_INVITE
    case NO_REPLY
    case LEFT_GAME
    case CANCELLED_INVITE
    case INVITE_TIMEOUT
    case INVITE_INVALID
    case TARGET_BUSY
    case TARGET_OFFLINE
    case MATCH_STARTING
    case SEARCH
    case SEARCH_HINT
    case NO_RESULTS
    case WORLD_RANKING
    case NO
    case PLAYER
    case RANK
    case RP
    case LOADING
    case YOU_NO
    case GUESTS_NOT_RANKED
    case MENU_SETTINGS
    case SETTING_MUSIC
    case SETTING_ON
    case SETTING_OFF
    case ACCOUNT_TITLE
    case STATUS_SIGNED_IN
    case STATUS_GUEST
    case STATUS_NONE
    case EXPLAIN_PGS_1
    case EXPLAIN_PGS_2
    case EXPLAIN_GUEST
    case BTN_PGS_SIGN_IN
    case BTN_GUEST
    case BTN_DELETE
    case CONFIRM_DELETE_1
    case CONFIRM_DELETE_2
    case YES_DELETE
    case NO_KEEP
    case DELETED
    case DELETING
    case PGS_UNAVAILABLE
    case PGS_NOT_CONFIGURED
    case PGS_SIGN_IN_FAILED
    case PGS_SERVER_ACCESS
    case SIGNED_IN_OK
    case SETUP_TITLE
    case SETUP_ONCE
    case PLAY_OFFLINE
    case MY_RANKING
    case RANK_BRONZE
    case RANK_SILVER
    case RANK_GOLD
    case RANK_PLATINUM
    case RANK_DIAMOND
    case RANK_MASTER

    /// O anki dildeki metin.
    func s() -> String { return `in`(Lang.current()) }

    func `in`(_ lang: Lang) -> String { return Txt.TEXTS[rawValue][lang.rawValue] }

    func count() -> Int { return Txt.TEXTS[rawValue].count }

    private static let TEXTS: [[String]] = [
        ["VIRUSHUNT", "VİRÜS AVI", "VIRUSHUNT", "VIRUSHUNT", "VIRUSHUNT", "VIRUSHUNT", "VIRUSHUNT", "VIRUSHUNT", "VIRUSHUNT", "VIRUSHUNT", "VIRUSHUNT", "VIRUSHUNT", "VIRUSHUNT", "VIRUSHUNT", "VIRUSHUNT", "VIRUSHUNT", "VIRUSHUNT", "VIRUSHUNT", "VIRUSHUNT", "VIRUSHUNT", "VIRUSHUNT", "VIRUSHUNT", "VIRUSHUNT", "VIRUSHUNT"], // TITLE_MAIN
        ["CAPSULE", "KAPSÜL", "CAPSULE", "CÁPSULA", "CAPSULE", "CÁPSULA", "KAPSUL", "КАПСУЛА", "CAPSULA", "KAPSUŁA", "CAPSULE", "КАПСУЛА", "CAPSULĂ", "KAPSLE", "KAPSZULA", "KAPSEL", "KAPSELI", "KAPSEL", "KAPSUL", "KAPSULA", "ΚΑΨΟΥΛΑ", "KAPSULA", "KAPSEL", "VIÊN NANG"], // TITLE_SUB
        ["SINGLE PLAYER", "TEK OYUNCU", "EINZELSPIELER", "UN JUGADOR", "UN JOUEUR", "UM JOGADOR", "SATU PEMAIN", "ОДИН ИГРОК", "GIOCATORE SINGOLO", "JEDEN GRACZ", "ÉÉN SPELER", "ОДИН ГРАВЕЦЬ", "UN JUCĂTOR", "JEDEN HRÁČ", "EGYJÁTÉKOS", "EN SPELARE", "YKSINPELI", "ÉN SPILLER", "SATU PEMAIN", "ISANG MANLALARO", "ΕΝΑΣ ΠΑΙΚΤΗΣ", "JEDEN HRÁČ", "ÉN SPILLER", "CHƠI ĐƠN"], // MENU_SINGLE
        ["ONLINE VS", "ONLİNE VS", "ONLINE VS", "ONLINE VS", "ONLINE VS", "ONLINE VS", "ONLINE VS", "ОНЛАЙН VS", "ONLINE VS", "ONLINE VS", "ONLINE VS", "ОНЛАЙН VS", "ONLINE VS", "ONLINE VS", "ONLINE VS", "ONLINE VS", "ONLINE VS", "ONLINE VS", "ONLINE VS", "ONLINE VS", "ONLINE VS", "ONLINE VS", "ONLINE VS", "ONLINE VS"], // MENU_ONLINE
        ["CPU VS", "CPU VS", "CPU VS", "CPU VS", "CPU VS", "CPU VS", "CPU VS", "CPU VS", "CPU VS", "CPU VS", "CPU VS", "CPU VS", "CPU VS", "CPU VS", "CPU VS", "CPU VS", "CPU VS", "CPU VS", "CPU VS", "CPU VS", "CPU VS", "CPU VS", "CPU VS", "CPU VS"], // MENU_CPU
        ["ACCOUNT", "HESAP", "KONTO", "CUENTA", "COMPTE", "CONTA", "AKUN", "АККАУНТ", "ACCOUNT", "KONTO", "ACCOUNT", "АКАУНТ", "CONT", "ÚČET", "FIÓK", "KONTO", "TILI", "KONTO", "AKAUN", "ACCOUNT", "ΛΟΓΑΡΙΑΣΜΟΣ", "ÚČET", "KONTO", "TÀI KHOẢN"], // MENU_ACCOUNT
        ["FEEDBACK", "GERİ BİLDİRİM", "FEEDBACK", "OPINIÓN", "AVIS", "FEEDBACK", "MASUKAN", "ОТЗЫВ", "FEEDBACK", "OPINIA", "FEEDBACK", "ВІДГУК", "PĂRERE", "NÁZOR", "VÉLEMÉNY", "FEEDBACK", "PALAUTE", "FEEDBACK", "MAKLUM BALAS", "FEEDBACK", "ΣΧΟΛΙΑ", "NÁZOR", "FEEDBACK", "GÓP Ý"], // FEEDBACK
        ["COMING SOON", "ÇOK YAKINDA", "DEMNÄCHST", "PRÓXIMAMENTE", "BIENTÔT", "EM BREVE", "SEGERA", "СКОРО", "IN ARRIVO", "WKRÓTCE", "BINNENKORT", "НЕЗАБАРОМ", "ÎN CURÂND", "JIŽ BRZY", "HAMAROSAN", "KOMMER SNART", "TULOSSA", "KOMMER SNART", "AKAN DATANG", "MALAPIT NA", "ΣΥΝΤΟΜΑ", "UŽ ČOSKORO", "KOMMER SNART", "SẮP RA MẮT"], // COMING_SOON
        ["1 PLAYER GAME", "TEK OYUNCU", "EINZELSPIELER", "UN JUGADOR", "UN JOUEUR", "UM JOGADOR", "SATU PEMAIN", "ОДИН ИГРОК", "1 GIOCATORE", "JEDEN GRACZ", "ÉÉN SPELER", "ОДИН ГРАВЕЦЬ", "UN JUCĂTOR", "JEDEN HRÁČ", "EGYJÁTÉKOS", "EN SPELARE", "YKSINPELI", "ÉN SPILLER", "SATU PEMAIN", "ISANG MANLALARO", "ΕΝΑΣ ΠΑΙΚΤΗΣ", "JEDEN HRÁČ", "ÉN SPILLER", "CHƠI ĐƠN"], // SET_TITLE_SINGLE
        ["ONLINE VS GAME", "ONLİNE VS", "ONLINE VS", "ONLINE VS", "ONLINE VS", "ONLINE VS", "ONLINE VS", "ОНЛАЙН VS", "ONLINE VS", "ONLINE VS", "ONLINE VS", "ОНЛАЙН VS", "ONLINE VS", "ONLINE VS", "ONLINE VS", "ONLINE VS", "ONLINE VS", "ONLINE VS", "ONLINE VS", "ONLINE VS", "ONLINE VS", "ONLINE VS", "ONLINE VS", "ONLINE VS"], // SET_TITLE_ONLINE
        ["CPU VS GAME", "CPU VS", "CPU VS", "CPU VS", "CPU VS", "CPU VS", "CPU VS", "CPU VS", "CPU VS", "CPU VS", "CPU VS", "CPU VS", "CPU VS", "CPU VS", "CPU VS", "CPU VS", "CPU VS", "CPU VS", "CPU VS", "CPU VS", "CPU VS", "CPU VS", "CPU VS", "CPU VS"], // SET_TITLE_CPU
        ["VIRUS LEVEL", "VİRÜS SEVİYESİ", "VIRUSSTUFE", "NIVEL DE VIRUS", "NIVEAU VIRUS", "NÍVEL DE VÍRUS", "LEVEL VIRUS", "УРОВЕНЬ ВИРУСА", "LIVELLO VIRUS", "POZIOM WIRUSÓW", "VIRUSNIVEAU", "РІВЕНЬ ВІРУСІВ", "NIVEL VIRUȘI", "ÚROVEŇ VIRŮ", "VÍRUSSZINT", "VIRUSNIVÅ", "VIRUSTASO", "VIRUSNIVEAU", "TAHAP VIRUS", "ANTAS NG VIRUS", "ΕΠΙΠΕΔΟ ΙΩΝ", "ÚROVEŇ VÍRUSOV", "VIRUSNIVÅ", "CẤP VIRUS"], // VIRUS_LEVEL
        ["SPEED", "HIZ", "TEMPO", "VELOCIDAD", "VITESSE", "VELOCIDADE", "KECEPATAN", "СКОРОСТЬ", "VELOCITÀ", "TEMPO", "SNELHEID", "ШВИДКІСТЬ", "VITEZĂ", "RYCHLOST", "SEBESSÉG", "FART", "NOPEUS", "FART", "KELAJUAN", "BILIS", "ΤΑΧΥΤΗΤΑ", "RÝCHLOSŤ", "FART", "TỐC ĐỘ"], // SPEED
        ["MUSIC TYPE", "MÜZİK", "MUSIK", "MÚSICA", "MUSIQUE", "MÚSICA", "MUSIK", "МУЗЫКА", "MUSICA", "MUZYKA", "MUZIEK", "МУЗИКА", "MUZICĂ", "HUDBA", "ZENE", "MUSIK", "MUSIIKKI", "MUSIK", "MUZIK", "MUSIKA", "ΜΟΥΣΙΚΗ", "HUDBA", "MUSIKK", "NHẠC"], // MUSIC_TYPE
        ["CPU LEVEL", "CPU SEVİYESİ", "CPU-STUFE", "NIVEL CPU", "NIVEAU CPU", "NÍVEL CPU", "LEVEL CPU", "УРОВЕНЬ CPU", "LIVELLO CPU", "POZIOM CPU", "CPU-NIVEAU", "РІВЕНЬ CPU", "NIVEL CPU", "ÚROVEŇ CPU", "CPU SZINT", "CPU-NIVÅ", "CPU-TASO", "CPU-NIVEAU", "TAHAP CPU", "ANTAS NG CPU", "ΕΠΙΠΕΔΟ CPU", "ÚROVEŇ CPU", "CPU-NIVÅ", "CẤP CPU"], // CPU_LEVEL
        ["START", "BAŞLA", "START", "JUGAR", "JOUER", "JOGAR", "MULAI", "СТАРТ", "VIA", "START", "START", "СТАРТ", "START", "START", "START", "START", "ALOITA", "START", "MULA", "SIMULA", "ΕΝΑΡΞΗ", "ŠTART", "START", "BẮT ĐẦU"], // START
        ["BACK", "GERİ", "ZURÜCK", "ATRÁS", "RETOUR", "VOLTAR", "KEMBALI", "НАЗАД", "TORNA", "WSTECZ", "TERUG", "НАЗАД", "ÎNAPOI", "ZPĚT", "VISSZA", "BAKÅT", "PALAA", "TILBAGE", "KEMBALI", "BALIK", "ΠΙΣΩ", "SPÄŤ", "TILBAKE", "TRỞ LẠI"], // BACK
        ["LOW", "YAVAŞ", "GERING", "BAJA", "LENTE", "BAIXA", "LAMBAT", "МЕДЛ.", "BASSA", "WOLNE", "LAAG", "ПОВІЛ.", "MICĂ", "NÍZKÁ", "LASSÚ", "LÅG", "HIDAS", "LAV", "RENDAH", "BAGAL", "ΧΑΜΗΛΗ", "NÍZKA", "LAV", "CHẬM"], // SPEED_LOW
        ["MED", "ORTA", "MITTEL", "MEDIA", "MOYEN", "MÉDIA", "SEDANG", "СРЕДН.", "MEDIA", "ŚREDNI", "MIDDEN", "СЕРЕД.", "MEDIE", "STŘED", "KÖZEP", "MEDEL", "KESKI", "MELLEM", "SEDANG", "GITNA", "ΜΕΣΑΙΑ", "STRED.", "MIDDEL", "VỪA"], // SPEED_MED
        ["HI", "HIZLI", "HOCH", "ALTA", "RAPIDE", "ALTA", "CEPAT", "БЫСТР.", "ALTA", "SZYBKI", "HOOG", "ШВИД.", "MARE", "VYSOKÁ", "GYORS", "HÖG", "NOPEA", "HØJ", "TINGGI", "BILIS", "ΥΨΗΛΗ", "VYSOKÁ", "HØY", "NHANH"], // SPEED_HI
        ["EASY", "KOLAY", "LEICHT", "FÁCIL", "FACILE", "FÁCIL", "MUDAH", "ЛЕГКО", "FACILE", "ŁATWY", "MAKKEL", "ЛЕГКО", "UȘOR", "LEHKÁ", "KÖNNYŰ", "LÄTT", "HELPPO", "LET", "MUDAH", "MADALI", "ΕΥΚΟΛΟ", "ĽAHKÁ", "LETT", "DỄ"], // DIFF_EASY
        ["MED", "ORTA", "MITTEL", "MEDIO", "MOYEN", "MÉDIO", "SEDANG", "СРЕДНЕ", "MEDIO", "ŚREDNI", "MIDDEN", "СЕРЕД.", "MEDIU", "STŘED", "KÖZEP", "MEDEL", "KESKI", "MELLEM", "SEDANG", "GITNA", "ΜΕΤΡΙΟ", "STRED.", "MIDDEL", "VỪA"], // DIFF_MED
        ["HARD", "ZOR", "SCHWER", "DIFÍC.", "DIFF.", "DIFÍC.", "SULIT", "ТРУДНО", "DIFF.", "TRUDNY", "MOEILK", "ВАЖКО", "GREU", "TĚŽKÁ", "NEHÉZ", "SVÅR", "VAIKEA", "SVÆR", "SUKAR", "HIRAP", "ΔΥΣΚ.", "ŤAŽKÁ", "VANSK.", "KHÓ"], // DIFF_HARD
        ["OFF", "KAPALI", "AUS", "NO", "AUCUNE", "SEM", "MATI", "ВЫКЛ.", "NO", "BRAK", "UIT", "ВИМК.", "FĂRĂ", "VYP.", "NINCS", "AV", "EI", "FRA", "TIADA", "WALA", "ΧΩΡΙΣ", "VYP.", "AV", "TẮT"], // MUSIC_OFF
        ["SPEED", "HIZ", "TEMPO", "VEL.", "VIT.", "VEL.", "LAJU", "ТЕМП", "VEL.", "TEMPO", "SNELH", "ШВИД.", "VIT.", "RYCHL", "SEB.", "FART", "NOP.", "FART", "LAJU", "BILIS", "ΤΑΧ.", "RÝCH.", "FART", "NHỊP"], // HUD_SPEED
        ["LOW", "YAVAŞ", "LANG", "BAJA", "LENT", "BAIXA", "PELAN", "НИЗ.", "BASSA", "WOLN", "LAAG", "НИЗ.", "MICĂ", "NÍZ.", "LASSÚ", "LÅG", "HIDAS", "LAV", "PELAN", "BABA", "ΧΑΜ.", "NÍZ.", "LAV", "CHẬM"], // HUD_SPEED_LOW
        ["MED", "ORTA", "MITT", "MED.", "MOY.", "MÉDIA", "BIASA", "СРЕД.", "MEDIA", "ŚRED", "MID", "СЕР.", "MED.", "STŘ.", "KÖZ.", "MED.", "KESKI", "MEL.", "BIASA", "KAT.", "ΜΕΣΗ", "STR.", "MID.", "VỪA"], // HUD_SPEED_MED
        ["HI", "HIZLI", "HOCH", "ALTA", "RAP.", "ALTA", "CEPAT", "ВЫС.", "ALTA", "SZYB", "HOOG", "ВИС.", "MARE", "VYS.", "GYORS", "HÖG", "NOPEA", "HØJ", "CEPAT", "TAAS", "ΥΨΗΛΗ", "VYS.", "HØY", "NHANH"], // HUD_SPEED_HI
        ["TOP", "REKOR", "REKORD", "RÉCORD", "RECORD", "RECORDE", "REKOR", "РЕКОРД", "RECORD", "REKORD", "RECORD", "РЕКОРД", "RECORD", "REKORD", "REKORD", "REKORD", "ENNÄTYS", "REKORD", "REKOD", "REKORD", "ΡΕΚΟΡ", "REKORD", "REKORD", "KỶ LỤC"], // TOP
        ["SCORE", "SKOR", "PUNKTE", "PUNTOS", "SCORE", "PONTOS", "SKOR", "ОЧКИ", "PUNTI", "WYNIK", "SCORE", "ОЧКИ", "SCOR", "SKÓRE", "PONT", "POÄNG", "PISTEET", "POINT", "MATA", "PUNTOS", "ΣΚΟΡ", "SKÓRE", "POENG", "ĐIỂM"], // SCORE
        ["LEVEL", "SEVİYE", "STUFE", "NIVEL", "NIVEAU", "NÍVEL", "LEVEL", "УРОВЕНЬ", "LIVELLO", "POZIOM", "LEVEL", "РІВЕНЬ", "NIVEL", "ÚROVEŇ", "SZINT", "NIVÅ", "TASO", "NIVEAU", "TAHAP", "ANTAS", "ΕΠΙΠΕΔΟ", "ÚROVEŇ", "NIVÅ", "CẤP ĐỘ"], // LEVEL
        ["VIRUS", "VİRÜS", "VIREN", "VIRUS", "VIRUS", "VÍRUS", "VIRUS", "ВИРУСЫ", "VIRUS", "WIRUSY", "VIRUS", "ВІРУСИ", "VIRUȘI", "VIRY", "VÍRUS", "VIRUS", "VIRUS", "VIRUS", "VIRUS", "VIRUS", "ΙΟΙ", "VÍRUSY", "VIRUS", "VIRUS"], // VIRUS
        ["PAUSED", "DURDU", "PAUSE", "PAUSA", "PAUSE", "PAUSA", "JEDA", "ПАУЗА", "PAUSA", "PAUZA", "PAUZE", "ПАУЗА", "PAUZĂ", "PAUZA", "SZÜNET", "PAUS", "TAUKO", "PAUSE", "JEDA", "HINTO", "ΠΑΥΣΗ", "PAUZA", "PAUSE", "TẠM DỪNG"], // PAUSED
        ["RESUME", "DEVAM", "WEITER", "CONTINUAR", "REPRENDRE", "CONTINUAR", "LANJUT", "ПРОДОЛЖИТЬ", "RIPRENDI", "WZNÓW", "VERDER", "ДАЛІ", "CONTINUĂ", "POKRAČOVAT", "FOLYTATÁS", "FORTSÄTT", "JATKA", "FORTSÆT", "SAMBUNG", "ITULOY", "ΣΥΝΕΧΕΙΑ", "POKRAČOVAŤ", "FORTSETT", "TIẾP TỤC"], // RESUME
        ["AD PRIVACY", "REKLAM GİZLİLİĞİ", "WERBE-DATENSCHUTZ", "PRIVACIDAD ANUNCIOS", "CONFIDENTIALITÉ PUB", "PRIVACIDADE ANÚNCIOS", "PRIVASI IKLAN", "КОНФИДЕНЦ. РЕКЛАМЫ", "PRIVACY ANNUNCI", "PRYWATNOŚĆ REKLAM", "PRIVACY ADVERTENTIES", "КОНФІДЕНЦ. РЕКЛАМИ", "CONFIDENȚ. RECLAME", "SOUKROMÍ REKLAM", "HIRDETÉSI ADATVÉDELEM", "ANNONSINTEGRITET", "MAINOSTEN TIETOSUOJA", "ANNONCEPRIVATLIV", "PRIVASI IKLAN", "PRIVACY NG AD", "ΑΠΟΡΡΗΤΟ ΔΙΑΦΗΜΙΣΕΩΝ", "SÚKROMIE REKLÁM", "ANNONSEPERSONVERN", "RIÊNG TƯ QUẢNG CÁO"], // AD_PRIVACY
        ["NO AD RIGHT NOW", "ŞU AN REKLAM YOK", "GERADE KEINE WERBUNG", "NO HAY ANUNCIO", "PAS DE PUB DISPO", "SEM ANÚNCIO AGORA", "IKLAN TIDAK ADA", "РЕКЛАМЫ НЕТ", "NESSUN ANNUNCIO", "BRAK REKLAMY", "GEEN ADVERTENTIE", "РЕКЛАМИ НЕМАЄ", "NICIO RECLAMĂ", "ŽÁDNÁ REKLAMA", "NINCS HIRDETÉS", "INGEN ANNONS NU", "EI MAINOSTA NYT", "INGEN ANNONCE NU", "TIADA IKLAN", "WALANG AD NGAYON", "ΚΑΜΙΑ ΔΙΑΦΗΜΙΣΗ", "ŽIADNA REKLAMA", "INGEN ANNONSE NÅ", "CHƯA CÓ QUẢNG CÁO"], // AD_UNAVAILABLE
        ["CONTINUE (AD)", "DEVAM (REKLAM)", "WEITER (WERBUNG)", "SEGUIR (ANUNCIO)", "REPRENDRE (PUB)", "SEGUIR (ANÚNCIO)", "LANJUT (IKLAN)", "ДАЛЕЕ (РЕКЛАМА)", "CONTINUA (SPOT)", "DALEJ (REKLAMA)", "VERDER (RECLAME)", "ДАЛІ (РЕКЛАМА)", "CONTINUĂ (RECLAMĂ)", "DÁL (REKLAMA)", "TOVÁBB (REKLÁM)", "FORTSÄTT (REKLAM)", "JATKA (MAINOS)", "FORTSÆT (REKLAME)", "SAMBUNG (IKLAN)", "ITULOY (AD)", "ΣΥΝΕΧΕΙΑ (ΔΙΑΦ.)", "ĎALEJ (REKLAMA)", "FORTSETT (ANNONSE)", "TIẾP (QUẢNG CÁO)"], // AD_CONTINUE
        ["MENU", "MENÜ", "MENÜ", "MENÚ", "MENU", "MENU", "MENU", "МЕНЮ", "MENU", "MENU", "MENU", "МЕНЮ", "MENIU", "MENU", "MENÜ", "MENY", "VALIKKO", "MENU", "MENU", "MENU", "ΜΕΝΟΥ", "MENU", "MENY", "MENU"], // MENU
        ["STAGE CLEAR", "BÖLÜM BİTTİ", "GESCHAFFT", "NIVEL SUPERADO", "NIVEAU RÉUSSI", "FASE CONCLUÍDA", "LEVEL SELESAI", "УРОВЕНЬ ПРОЙДЕН", "LIVELLO SUPERATO", "POZIOM ZALICZONY", "LEVEL GEHAALD", "РІВЕНЬ ПРОЙДЕНО", "NIVEL TERMINAT", "ÚROVEŇ SPLNĚNA", "SZINT TELJESÍTVE", "NIVÅ KLAR", "TASO LÄPÄISTY", "NIVEAU KLARET", "TAHAP SELESAI", "TAPOS ANG ANTAS", "ΤΕΛΟΣ ΠΙΣΤΑΣ", "ÚROVEŇ SPLNENÁ", "NIVÅ FULLFØRT", "HOÀN THÀNH MÀN"], // STAGE_CLEAR
        ["GAME OVER", "OYUN BİTTİ", "GAME OVER", "FIN DEL JUEGO", "PARTIE FINIE", "FIM DE JOGO", "GAME OVER", "ИГРА ОКОНЧЕНА", "GAME OVER", "KONIEC GRY", "GAME OVER", "КІНЕЦЬ ГРИ", "JOC TERMINAT", "KONEC HRY", "VÉGE A JÁTÉKNAK", "SPELET SLUT", "PELI OHI", "SPILLET SLUT", "PERMAINAN TAMAT", "TAPOS ANG LARO", "GAME OVER", "KONIEC HRY", "SPILLET ER SLUTT", "KẾT THÚC"], // GAME_OVER
        ["PRESS START", "DEVAM İÇİN DOKUN", "DRÜCKE START", "TOCA PARA SEGUIR", "TOUCHE L'ÉCRAN", "TOQUE PARA JOGAR", "KETUK UNTUK MAIN", "НАЖМИТЕ СТАРТ", "TOCCA E GIOCA", "DOTKNIJ, BY GRAĆ", "TIK OM TE SPELEN", "ТОРКНІТЬСЯ", "ATINGE ȘI JOACĂ", "KLEPNI A HRAJ", "KOPPINTS!", "TRYCK OCH SPELA", "NAPAUTA JA PELAA", "TRYK OG SPIL", "SENTUH DAN MAIN", "TAP PARA MAGLARO", "ΠΑΤΑ ΕΝΑΡΞΗ", "ŤUKNI A HRAJ", "TRYKK OG SPILL", "CHẠM ĐỂ CHƠI"], // PRESS_START
        ["YOU", "SEN", "DU", "TÚ", "TOI", "VOCÊ", "KAMU", "ВЫ", "TU", "TY", "JIJ", "ВИ", "TU", "TY", "TE", "DU", "SINÄ", "DIG", "ANDA", "IKAW", "ΕΣΥ", "TY", "DEG", "BẠN"], // YOU
        ["CPU", "CPU", "CPU", "CPU", "CPU", "CPU", "CPU", "CPU", "CPU", "CPU", "CPU", "CPU", "CPU", "CPU", "CPU", "CPU", "CPU", "CPU", "CPU", "CPU", "CPU", "CPU", "CPU", "CPU"], // CPU
        ["RIVAL", "RAKİP", "GEGNER", "RIVAL", "RIVAL", "RIVAL", "LAWAN", "ВРАГ", "RIVALE", "RYWAL", "TEGENSTANDER", "СУПЕРНИК", "RIVAL", "SOUPEŘ", "ELLENFÉL", "MOTSTÅNDARE", "VASTUSTAJA", "MODSTANDER", "LAWAN", "KALABAN", "ΑΝΤΙΠΑΛΟΣ", "SÚPER", "MOTSTANDER", "ĐỐI THỦ"], // RIVAL
        ["VS", "VS", "VS", "VS", "VS", "VS", "VS", "VS", "VS", "VS", "VS", "VS", "VS", "VS", "VS", "VS", "VS", "VS", "VS", "VS", "VS", "VS", "VS", "VS"], // VS
        ["YOU WIN", "KAZANDIN", "GEWONNEN", "GANASTE", "TU AS GAGNÉ", "VOCÊ VENCEU", "KAMU MENANG", "ПОБЕДА", "HAI VINTO", "WYGRANA", "GEWONNEN", "ПЕРЕМОГА", "AI CÂȘTIGAT", "VÝHRA", "NYERTÉL", "DU VANN", "VOITIT", "DU VANDT", "ANDA MENANG", "PANALO KA", "ΝΙΚΗΣΕΣ", "VÝHRA", "DU VANT", "BẠN THẮNG"], // YOU_WIN
        ["YOU LOSE", "KAYBETTİN", "VERLOREN", "PERDISTE", "TU AS PERDU", "VOCÊ PERDEU", "KAMU KALAH", "ПОРАЖЕНИЕ", "HAI PERSO", "PRZEGRANA", "VERLOREN", "ПОРАЗКА", "AI PIERDUT", "PROHRA", "VESZTETTÉL", "DU FÖRLORADE", "HÄVISIT", "DU TABTE", "ANDA KALAH", "TALO KA", "ΕΧΑΣΕΣ", "PREHRA", "DU TAPTE", "BẠN THUA"], // YOU_LOSE
        ["DRAW", "BERABERE", "REMIS", "EMPATE", "ÉGALITÉ", "EMPATE", "SERI", "НИЧЬЯ", "PAREGGIO", "REMIS", "GELIJKSPEL", "НІЧИЯ", "EGALITATE", "REMÍZA", "DÖNTETLEN", "OAVGJORT", "TASAPELI", "UAFGJORT", "SERI", "TABLA", "ΙΣΟΠΑΛΙΑ", "REMÍZA", "UAVGJORT", "HÒA"], // DRAW
        ["RIVAL LEFT", "RAKİP ÇIKTI", "GEGNER WEG", "RIVAL SALIÓ", "RIVAL PARTI", "RIVAL SAIU", "LAWAN KELUAR", "ВРАГ УШЁЛ", "RIVALE USCITO", "RYWAL WYSZEDŁ", "TEGENST. WEG", "СУПЕРН. ВИЙШОВ", "RIVALUL A IEȘIT", "SOUPEŘ ODEŠEL", "ELLENFÉL KILÉPETT", "MOTST. LÄMNADE", "VASTUST. LÄHTI", "MODST. GIK", "LAWAN KELUAR", "UMALIS ANG KALABAN", "ΑΝΤΙΠ. ΕΦΥΓΕ", "SÚPER ODIŠIEL", "MOTST. GIKK", "ĐỐI THỦ RỜI"], // RIVAL_LEFT
        ["CONNECTION LOST", "BAĞLANTI KOPTU", "VERBINDUNG WEG", "CONEXIÓN PERDIDA", "CONNEXION PERDUE", "CONEXÃO PERDIDA", "KONEKSI TERPUTUS", "СВЯЗЬ ПОТЕРЯНА", "CONNESSIONE PERSA", "UTRACONO POŁĄCZENIE", "VERBINDING VERBROKEN", "З'ЄДНАННЯ ВТРАЧЕНО", "CONEXIUNE PIERDUTĂ", "SPOJENÍ PŘERUŠENO", "MEGSZAKADT A KAPCSOLAT", "ANSLUTNINGEN BRÖTS", "YHTEYS KATKESI", "FORBINDELSEN AFBRUDT", "SAMBUNGAN TERPUTUS", "NAWALA ANG KONEKSYON", "Η ΣΥΝΔΕΣΗ ΧΑΘΗΚΕ", "SPOJENIE PRERUŠENÉ", "FORBINDELSEN BRUTT", "MẤT KẾT NỐI"], // CONNECTION_LOST
        ["SIGNING IN", "GİRİŞ YAPILIYOR", "ANMELDUNG", "INICIANDO SESIÓN", "IDENTIFICATION", "ENTRANDO", "MASUK", "ВХОД", "ACCESSO IN CORSO", "LOGOWANIE", "INLOGGEN", "ВХІД", "CONECTARE", "PŘIHLAŠOVÁNÍ", "BEJELENTKEZÉS", "LOGGAR IN", "KIRJAUDUTAAN", "LOGGER IND", "LOG MASUK", "NAGSA-SIGN IN", "ΕΙΣΟΔΟΣ", "PRIHLASOVANIE", "LOGGER INN", "ĐANG ĐĂNG NHẬP"], // SIGNING_IN
        ["CONNECTING", "BAĞLANIYOR", "VERBINDEN", "CONECTANDO", "CONNEXION", "CONECTANDO", "MENGHUBUNGKAN", "ПОДКЛЮЧЕНИЕ", "CONNESSIONE", "ŁĄCZENIE", "VERBINDEN", "З'ЄДНАННЯ", "SE CONECTEAZĂ", "PŘIPOJOVÁNÍ", "KAPCSOLÓDÁS", "ANSLUTER", "YHDISTETÄÄN", "FORBINDER", "MENYAMBUNG", "KUMOKONEKTA", "ΣΥΝΔΕΣΗ", "PRIPÁJANIE", "KOBLER TIL", "ĐANG KẾT NỐI"], // CONNECTING
        ["ACCOUNT: ", "HESAP: ", "KONTO: ", "CUENTA: ", "COMPTE: ", "CONTA: ", "AKUN: ", "АККАУНТ: ", "ACCOUNT: ", "KONTO: ", "ACCOUNT: ", "АКАУНТ: ", "CONT: ", "ÚČET: ", "FIÓK: ", "KONTO: ", "TILI: ", "KONTO: ", "AKAUN: ", "ACCOUNT: ", "ΛΟΓΑΡΙΑΣΜΟΣ: ", "ÚČET: ", "KONTO: ", "TÀI KHOẢN: "], // ACCOUNT_PREFIX
        ["RETRY", "TEKRAR", "ERNEUT", "REINTENTAR", "RÉESSAYER", "REPETIR", "ULANGI", "ПОВТОР", "RIPROVA", "PONÓW", "OPNIEUW", "ЩЕ РАЗ", "REÎNCEARCĂ", "ZNOVU", "ÚJRA", "FÖRSÖK IGEN", "YRITÄ UUDELLEEN", "PRØV IGEN", "CUBA LAGI", "SUBUKAN ULIT", "ΞΑΝΑ", "ZNOVA", "PRØV IGJEN", "THỬ LẠI"], // RETRY
        ["SIGN IN FAILED", "GİRİŞ BAŞARISIZ", "ANMELDUNG FEHLGESCHLAGEN", "NO SE PUDO ENTRAR", "ÉCHEC DE CONNEXION", "FALHA AO ENTRAR", "GAGAL MASUK", "ОШИБКА ВХОДА", "ACCESSO FALLITO", "LOGOWANIE NIEUDANE", "INLOGGEN MISLUKT", "НЕ ВДАЛОСЯ УВІЙТИ", "CONECTARE EȘUATĂ", "PŘIHLÁŠENÍ SELHALO", "SIKERTELEN BELÉPÉS", "INLOGGNING MISSLYCKADES", "KIRJAUTUMINEN EPÄONNISTUI", "LOGIN MISLYKKEDES", "GAGAL LOG MASUK", "HINDI NAKA-SIGN IN", "Η ΣΥΝΔΕΣΗ ΑΠΕΤΥΧΕ", "PRIHLÁSENIE ZLYHALO", "INNLOGGING MISLYKTES", "ĐĂNG NHẬP THẤT BẠI"], // SIGN_IN_FAILED
        ["ERROR", "HATA", "FEHLER", "ERROR", "ERREUR", "ERRO", "KESALAHAN", "ОШИБКА", "ERRORE", "BŁĄD", "FOUT", "ПОМИЛКА", "EROARE", "CHYBA", "HIBA", "FEL", "VIRHE", "FEJL", "RALAT", "ERROR", "ΣΦΑΛΜΑ", "CHYBA", "FEIL", "LỖI"], // ERROR
        ["NETWORK ERROR", "AĞ HATASI", "NETZWERKFEHLER", "ERROR DE RED", "ERREUR RÉSEAU", "ERRO DE REDE", "GALAT JARINGAN", "ОШИБКА СЕТИ", "ERRORE DI RETE", "BŁĄD SIECI", "NETWERKFOUT", "ПОМИЛКА МЕРЕЖІ", "EROARE DE REȚEA", "CHYBA SÍTĚ", "HÁLÓZATI HIBA", "NÄTVERKSFEL", "VERKKOVIRHE", "NETVÆRKSFEJL", "RALAT RANGKAIAN", "ERROR SA NETWORK", "ΣΦΑΛΜΑ ΔΙΚΤΥΟΥ", "CHYBA SIETE", "NETTVERKSFEIL", "LỖI MẠNG"], // NETWORK_ERROR
        ["SERVER UNAVAILABLE", "SUNUCUYA ULAŞILAMADI", "SERVER NICHT ERREICHBAR", "SERVIDOR NO DISPONIBLE", "SERVEUR INDISPONIBLE", "SERVIDOR INDISPONÍVEL", "SERVER TIDAK TERSEDIA", "СЕРВЕР НЕДОСТУПЕН", "SERVER NON DISPONIBILE", "SERWER NIEDOSTĘPNY", "SERVER NIET BEREIKBAAR", "СЕРВЕР НЕДОСТУПНИЙ", "SERVER INDISPONIBIL", "SERVER JE NEDOSTUPNÝ", "A SZERVER NEM ÉRHETŐ EL", "SERVERN ÄR INTE TILLGÄNGLIG", "PALVELIN EI VASTAA", "SERVEREN ER IKKE TILGÆNGELIG", "PELAYAN TIDAK TERSEDIA", "HINDI MAABOT ANG SERVER", "Ο ΔΙΑΚΟΜΙΣΤΗΣ ΔΕΝ ΑΠΑΝΤΑ", "SERVER JE NEDOSTUPNÝ", "SERVEREN ER UTILGJENGELIG", "MÁY CHỦ KHÔNG PHẢN HỒI"], // SERVER_UNAVAILABLE
        ["WINS", "GALİBİYET", "SIEGE", "VICTORIAS", "VICTOIRES", "VITÓRIAS", "MENANG", "ПОБЕДЫ", "VITTORIE", "WYGRANE", "WINST", "ПЕРЕМОГИ", "VICTORII", "VÝHRY", "GYŐZELEM", "VINSTER", "VOITOT", "SEJRE", "MENANG", "PANALO", "ΝΙΚΕΣ", "VÝHRY", "SEIRE", "THẮNG"], // WINS
        ["LOSSES", "MAĞLUBİYET", "NIEDERLAGEN", "DERROTAS", "DÉFAITES", "DERROTAS", "KALAH", "ПОРАЖЕНИЯ", "SCONFITTE", "PRZEGRANE", "VERLIES", "ПОРАЗКИ", "ÎNFRÂNGERI", "PROHRY", "VERESÉG", "FÖRLUSTER", "TAPIOT", "NEDERLAG", "KALAH", "TALO", "ΗΤΤΕΣ", "PREHRY", "TAP", "THUA"], // LOSSES
        ["REFRESH", "GÜNCELLE", "AKTUALISIEREN", "ACTUALIZAR", "ACTUALISER", "ATUALIZAR", "PERBARUI", "ОБНОВИТЬ", "AGGIORNA", "ODŚWIEŻ", "VERNIEUWEN", "ОНОВИТИ", "ACTUALIZEAZĂ", "OBNOVIT", "FRISSÍTÉS", "UPPDATERA", "PÄIVITÄ", "OPDATER", "SEGAR SEMULA", "I-REFRESH", "ΑΝΑΝΕΩΣΗ", "OBNOVIŤ", "OPPDATER", "LÀM MỚI"], // REFRESH
        ["HOW TO PLAY", "NASIL OYNANIR", "SPIELANLEITUNG", "CÓMO JUGAR", "COMMENT JOUER", "COMO JOGAR", "CARA BERMAIN", "КАК ИГРАТЬ", "COME SI GIOCA", "JAK GRAĆ", "HOE SPEEL JE", "ЯК ГРАТИ", "CUM SE JOACĂ", "JAK HRÁT", "HOGYAN JÁTSSZ", "SÅ SPELAR DU", "NÄIN PELAAT", "SÅDAN SPILLER DU", "CARA BERMAIN", "PAANO MAGLARO", "ΠΩΣ ΠΑΙΖΕΤΑΙ", "AKO HRAŤ", "SLIK SPILLER DU", "CÁCH CHƠI"], // HOW_TO_PLAY
        ["PRIVACY POLICY", "GİZLİLİK POLİTİKASI", "DATENSCHUTZ", "PRIVACIDAD", "CONFIDENTIALITÉ", "PRIVACIDADE", "KEBIJAKAN PRIVASI", "КОНФИДЕНЦИАЛЬНОСТЬ", "INFORMATIVA PRIVACY", "POLITYKA PRYWATNOŚCI", "PRIVACYBELEID", "КОНФІДЕНЦІЙНІСТЬ", "CONFIDENȚIALITATE", "OCHRANA SOUKROMÍ", "ADATVÉDELEM", "INTEGRITETSPOLICY", "TIETOSUOJA", "PRIVATLIVSPOLITIK", "DASAR PRIVASI", "PATAKARAN SA PRIVACY", "ΠΟΛΙΤΙΚΗ ΑΠΟΡΡΗΤΟΥ", "OCHRANA SÚKROMIA", "PERSONVERN", "CHÍNH SÁCH RIÊNG TƯ"], // PRIVACY_POLICY
        ["WORLD NO.", "DÜNYA NO.", "WELT NR.", "PUESTO ", "RANG ", "POSIÇÃO ", "PERINGKAT ", "МЕСТО ", "MONDO N.", "ŚWIAT NR.", "WERELD NR.", "МІСЦЕ ", "LOC", "SVĚT Č.", "VILÁG #", "VÄRLD NR", "MAAILMA NRO", "VERDEN NR.", "DUNIA NO.", "MUNDO BLG.", "ΠΑΓΚΟΣΜΙΑ #", "SVET Č.", "VERDEN NR.", "THẾ GIỚI #"], // WORLD_NO
        ["UNRANKED", "SIRASIZ", "OHNE RANG", "SIN RANGO", "NON CLASSÉ", "SEM RANK", "TANPA RANK", "БЕЗ РАНГА", "SENZA RANGO", "BEZ RANGI", "ZONDER RANG", "БЕЗ РАНГУ", "FĂRĂ RANG", "BEZ HODNOCENÍ", "RANG NÉLKÜL", "OGRADERAD", "EI SIJAA", "UDEN RANG", "TIADA KEDUDUKAN", "WALANG RANGGO", "ΧΩΡΙΣ ΚΑΤΑΤΑΞΗ", "BEZ HODNOTENIA", "UTEN RANGERING", "CHƯA XẾP HẠNG"], // UNRANKED
        ["NEXT: ", "HEDEF: ", "ZIEL: ", "META: ", "BUT: ", "META: ", "TARGET: ", "ЦЕЛЬ: ", "PROSS: ", "CEL: ", "DOEL: ", "ДАЛІ: ", "URM: ", "DALŠÍ: ", "KÖV: ", "NÄSTA: ", "SEUR: ", "NÆSTE: ", "SETERUSNYA: ", "SUSUNOD: ", "ΕΠΟΜ.: ", "ĎALŠÍ: ", "NESTE: ", "TIẾP: "], // NEXT_RANK
        ["TOP RANK", "EN ÜST", "HÖCHSTER RANG", "RANGO MÁXIMO", "RANG MAX", "RANK MÁXIMO", "TERTINGGI", "ВЫСШИЙ РАНГ", "MASSIMO", "SZCZYT", "TOP", "ВЕРШИНА", "VÂRF", "VRCHOL", "CSÚCS", "TOPP", "HUIPPU", "TOP", "TERTINGGI", "PINAKAMATAAS", "ΚΟΡΥΦΗ", "VRCHOL", "TOPP", "ĐỈNH CAO"], // TOP_RANK
        ["PLAY GAMES", "PLAY GAMES", "PLAY GAMES", "PLAY GAMES", "PLAY GAMES", "PLAY GAMES", "PLAY GAMES", "PLAY GAMES", "PLAY GAMES", "PLAY GAMES", "PLAY GAMES", "PLAY GAMES", "PLAY GAMES", "PLAY GAMES", "PLAY GAMES", "PLAY GAMES", "PLAY GAMES", "PLAY GAMES", "PLAY GAMES", "PLAY GAMES", "PLAY GAMES", "PLAY GAMES", "PLAY GAMES", "PLAY GAMES"], // PLAY_GAMES
        ["GUEST", "MİSAFİR", "GAST", "INVITADO", "INVITÉ", "CONVIDADO", "TAMU", "ГОСТЬ", "OSPITE", "GOŚĆ", "GAST", "ГІСТЬ", "OASPETE", "HOST", "VENDÉG", "GÄST", "VIERAS", "GÆST", "TETAMU", "BISITA", "ΕΠΙΣΚΕΠΤΗΣ", "HOSŤ", "GJEST", "KHÁCH"], // GUEST
        ["LV ", "SV ", "ST ", "NV ", "NV ", "NV ", "LV ", "УР ", "LV ", "POZ ", "LV ", "РВ ", "NV ", "ÚR ", "SZ ", "NV ", "TS ", "NV ", "TP ", "AN ", "ΕΠ. ", "ÚR. ", "NV ", "CẤP "], // LV
        ["PLAYERS ONLINE ", "ONLİNE OYUNCU ", "SPIELER ONLINE ", "EN LÍNEA: ", "EN LIGNE: ", "ONLINE: ", "PEMAIN ONLINE ", "ОНЛАЙН: ", "GIOCATORI ONLINE ", "GRACZE ONLINE ", "SPELERS ONLINE ", "ГРАВЦІ ОНЛАЙН ", "JUCĂTORI ONLINE ", "HRÁČI ONLINE ", "JÁTÉKOSOK ONLINE ", "SPELARE ONLINE ", "PELAAJIA ONLINE ", "SPILLERE ONLINE ", "PEMAIN ONLINE ", "ONLINE NA MANLALARO ", "ΠΑΙΚΤΕΣ ONLINE ", "HRÁČI ONLINE ", "SPILLERE ONLINE ", "NGƯỜI CHƠI ONLINE "], // PLAYERS_ONLINE
        ["NOBODY HERE YET", "HENÜZ KİMSE YOK", "NOCH NIEMAND DA", "AÚN NO HAY NADIE", "PERSONNE ICI", "NINGUÉM AQUI", "BELUM ADA ORANG", "ПОКА НИКОГО", "ANCORA NESSUNO", "NA RAZIE NIKOGO", "NOG NIEMAND HIER", "ТУТ ЩЕ НІКОГО", "NIMENI AICI ÎNCĂ", "ZATÍM TU NIKDO NENÍ", "MÉG NINCS ITT SENKI", "INGEN HÄR ÄN", "TÄÄLLÄ EI VIELÄ KETÄÄN", "INGEN HER ENDNU", "BELUM ADA SESIAPA", "WALA PANG TAO DITO", "ΚΑΝΕΙΣ ΕΔΩ ΑΚΟΜΑ", "ZATIAĽ TU NIKTO", "INGEN HER ENNÅ", "CHƯA CÓ AI"], // NOBODY_HERE
        ["TRY QUICK MATCH", "HIZLI EŞLEŞME DENE", "SCHNELLES SPIEL", "PRUEBA PARTIDA RÁPIDA", "ESSAIE LE MATCH RAPIDE", "TENTE PARTIDA RÁPIDA", "COBA LAGA CEPAT", "ПОПРОБУЙ БЫСТРЫЙ МАТЧ", "PROVA PARTITA RAPIDA", "SPRÓBUJ SZYBKIEJ GRY", "PROBEER SNEL SPEL", "СПРОБУЙ ШВИДКУ ГРУ", "ÎNCEARCĂ MECI RAPID", "ZKUS RYCHLOU HRU", "PRÓBÁLD A GYORS MECCSET", "TESTA SNABBMATCH", "KOKEILE PIKAPELIÄ", "PRØV HURTIG KAMP", "CUBA PERLAWANAN PANTAS", "SUBUKAN ANG QUICK MATCH", "ΠΑΙΞΕ ΑΜΕΣΟ ΑΓΩΝΑ", "SKÚS RÝCHLU HRU", "PRØV HURTIGKAMP", "THỬ GHÉP NHANH"], // TRY_QUICK_MATCH
        ["INVITED", "DAVETLİ", "EINGELADEN", "INVITADO", "INVITÉ", "CONVIDADO", "DIUNDANG", "ПРИГЛАШЁН", "INVITATO", "ZAPROSZONY", "UITGENODIGD", "ЗАПРОШЕНО", "INVITAT", "POZVÁN", "MEGHÍVVA", "INBJUDEN", "KUTSUTTU", "INVITERET", "DIJEMPUT", "INIMBITA", "ΠΡΟΣΚΛ.", "POZVANÝ", "INVITERT", "ĐÃ MỜI"], // INVITED
        ["IN MATCH", "MAÇTA", "IM SPIEL", "EN JUEGO", "EN MATCH", "EM JOGO", "BERMAIN", "В ИГРЕ", "IN GARA", "GRA", "SPEELT", "У МАТЧІ", "ÎN MECI", "VE HŘE", "MECCSBEN", "I MATCH", "PELISSÄ", "I KAMP", "BERMAIN", "NASA LARO", "ΣΕ ΑΓΩΝΑ", "V HRE", "I KAMP", "ĐANG ĐẤU"], // IN_MATCH
        ["PLAYER IS IN A MATCH", "OYUNCU MAÇTA", "SPIELER IST IM SPIEL", "EL JUGADOR ESTÁ JUGANDO", "LE JOUEUR EST EN MATCH", "O JOGADOR ESTÁ EM JOGO", "PEMAIN SEDANG BERMAIN", "ИГРОК СЕЙЧАС В ИГРЕ", "GIOCATORE IN PARTITA", "GRACZ JEST W GRZE", "SPELER IS IN EEN SPEL", "ГРАВЕЦЬ У МАТЧІ", "JUCĂTORUL E ÎN MECI", "HRÁČ PRÁVĚ HRAJE", "A JÁTÉKOS MECCSBEN VAN", "SPELAREN ÄR I EN MATCH", "PELAAJA ON PELISSÄ", "SPILLEREN ER I EN KAMP", "PEMAIN SEDANG BERMAIN", "NASA LARO ANG MANLALARO", "Ο ΠΑΙΚΤΗΣ ΠΑΙΖΕΙ ΗΔΗ", "HRÁČ PRÁVE HRÁ", "SPILLEREN ER I EN KAMP", "NGƯỜI CHƠI ĐANG ĐẤU"], // PLAYER_BUSY
        ["SEARCHING", "ARANIYOR", "SUCHE", "BUSCANDO", "RECHERCHE", "BUSCANDO", "MENCARI", "ПОИСК", "RICERCA", "SZUKANIE", "ZOEKEN", "ПОШУК", "CĂUTARE", "HLEDÁNÍ", "KERESÉS", "SÖKER", "HAETAAN", "SØGER", "MENCARI", "NAGHAHANAP", "ΑΝΑΖΗΤΗΣΗ", "HĽADÁ SA", "SØKER", "ĐANG TÌM"], // SEARCHING
        ["QUICK MATCH", "HIZLI EŞLEŞME", "SCHNELLES SPIEL", "PARTIDA RÁPIDA", "MATCH RAPIDE", "PARTIDA RÁPIDA", "LAGA CEPAT", "БЫСТРЫЙ МАТЧ", "PARTITA RAPIDA", "SZYBKA GRA", "SNEL SPEL", "ШВИДКА ГРА", "MECI RAPID", "RYCHLÁ HRA", "GYORS MECCS", "SNABBMATCH", "PIKAPELI", "HURTIG KAMP", "MAIN PANTAS", "QUICK MATCH", "ΑΜΕΣΟΣ ΑΓΩΝΑΣ", "RÝCHLA HRA", "HURTIGKAMP", "GHÉP NHANH"], // QUICK_MATCH
        ["CANCEL INVITE", "DAVETİ İPTAL ET", "ABBRECHEN", "CANCELAR", "ANNULER", "CANCELAR", "BATALKAN", "ОТМЕНИТЬ", "ANNULLA INVITO", "ANULUJ ZAPROSZ.", "ANNULEREN", "СКАСУВАТИ", "ANULEAZĂ", "ZRUŠIT POZVÁNÍ", "VISSZAVONÁS", "AVBRYT INBJ.", "PERU KUTSU", "ANNULLER", "BATAL JEMPUTAN", "IKANSELA", "ΑΚΥΡΩΣΗ", "ZRUŠIŤ POZVANIE", "AVBRYT", "HỦY LỜI MỜI"], // CANCEL_INVITE
        ["LEADERBOARD", "LİDER TABLOSU", "BESTENLISTE", "CLASIFICACIÓN", "CLASSEMENT", "CLASSIFICAÇÃO", "PAPAN SKOR", "РЕЙТИНГ", "CLASSIFICA", "RANKING", "RANGLIJST", "РЕЙТИНГ", "CLASAMENT", "ŽEBŘÍČEK", "RANGLISTA", "TOPPLISTA", "TULOSLISTA", "RANGLISTE", "PAPAN MARKAH", "LEADERBOARD", "ΚΑΤΑΤΑΞΗ", "REBRÍČEK", "TOPPLISTE", "BẢNG XẾP HẠNG"], // LEADERBOARD
        ["ACCEPT", "KABUL", "ANNEHMEN", "ACEPTAR", "ACCEPTER", "ACEITAR", "TERIMA", "ПРИНЯТЬ", "ACCETTA", "PRZYJMIJ", "ACCEPTEER", "ПРИЙНЯТИ", "ACCEPTĂ", "PŘIJMOUT", "ELFOGAD", "ACCEPTERA", "HYVÄKSY", "ACCEPTER", "TERIMA", "TANGGAPIN", "ΑΠΟΔΟΧΗ", "PRIJAŤ", "GODTA", "CHẤP NHẬN"], // ACCEPT
        ["DECLINE", "REDDET", "ABLEHNEN", "RECHAZAR", "REFUSER", "RECUSAR", "TOLAK", "ОТКЛОНИТЬ", "RIFIUTA", "ODRZUĆ", "WEIGER", "ВІДХИЛИТИ", "REFUZĂ", "ODMÍTNOUT", "ELUTASÍT", "AVBÖJ", "HYLKÄÄ", "AFVIS", "TOLAK", "TANGGIHAN", "ΑΠΟΡΡΙΨΗ", "ODMIETNUŤ", "AVSLÅ", "TỪ CHỐI"], // DECLINE
        [" INVITES YOU", " DAVET ETTİ", " LÄDT EIN", " TE INVITA", " T'INVITE", " TE CONVIDA", " MENGAJAKMU", " ЗОВЁТ ТЕБЯ", " TI INVITA", " ZAPRASZA CIĘ", " NODIGT JE UIT", " ЗАПРОШУЄ ВАС", " TE INVITĂ", " TĚ ZVE", " MEGHÍVOTT", " BJUDER IN DIG", " KUTSUU SINUT", " INVITERER DIG", " MENJEMPUT ANDA", " AY NAG-IMBITA", " ΣΕ ΠΡΟΣΚΑΛΕΙ", " ŤA POZÝVA", " INVITERER DEG", " MỜI BẠN"], // INVITES_YOU
        ["INVITED ", "DAVET: ", "EINGELADEN: ", "INVITADO: ", "INVITÉ: ", "CONVIDADO: ", "DIUNDANG: ", "ПРИГЛАШЁН: ", "INVITATO ", "ZAPROSZONO ", "UITGENODIGD: ", "ЗАПРОШЕНО: ", "INVITAT: ", "POZVÁN: ", "MEGHÍVVA: ", "INBJUDEN: ", "KUTSUTTU: ", "INVITERET: ", "DIJEMPUT: ", "INIMBITA: ", "ΠΡΟΣΚΛΗΘΗΚΕ: ", "POZVANÝ: ", "INVITERT: ", "ĐÃ MỜI: "], // INVITED_TOAST
        ["CANCEL YOUR INVITE FIRST", "ÖNCE DAVETİNİ İPTAL ET", "ERST EINLADUNG ABBRECHEN", "CANCELA TU INVITACIÓN", "ANNULE TON INVITATION", "CANCELE SEU CONVITE", "BATALKAN UNDANGANMU DULU", "СНАЧАЛА ОТМЕНИ ПРИГЛАШЕНИЕ", "PRIMA ANNULLA L'INVITO", "NAJPIERW ANULUJ ZAPROSZENIE", "ANNULEER EERST JE UITNODIGING", "СПЕРШУ СКАСУЙТЕ ЗАПРОШЕННЯ", "ANULEAZĂ ÎNTÂI INVITAȚIA", "NEJDŘÍV ZRUŠ SVÉ POZVÁNÍ", "ELŐBB VOND VISSZA A MEGHÍVÁST", "AVBRYT DIN INBJUDAN FÖRST", "PERU ENSIN OMA KUTSUSI", "ANNULLER DIN INVITATION FØRST", "BATALKAN JEMPUTAN ANDA DULU", "IKANSELA MUNA ANG IMBITASYON MO", "ΑΚΥΡΩΣΕ ΠΡΩΤΑ ΤΗΝ ΠΡΟΣΚΛΗΣΗ", "NAJPRV ZRUŠ SVOJE POZVANIE", "AVBRYT INVITASJONEN FØRST", "HÃY HỦY LỜI MỜI TRƯỚC"], // CANCEL_FIRST
        ["INVITE FAILED", "DAVET BAŞARISIZ", "EINLADUNG FEHLGESCHLAGEN", "NO SE PUDO INVITAR", "ÉCHEC DE L'INVITATION", "FALHA NO CONVITE", "GAGAL MENGUNDANG", "ОШИБКА ПРИГЛАШЕНИЯ", "INVITO FALLITO", "ZAPROSZENIE NIEUDANE", "UITNODIGEN MISLUKT", "ЗАПРОШЕННЯ НЕ НАДІСЛАНО", "INVITAȚIE EȘUATĂ", "POZVÁNÍ SELHALO", "SIKERTELEN MEGHÍVÁS", "INBJUDAN MISSLYCKADES", "KUTSU EPÄONNISTUI", "INVITATION MISLYKKEDES", "JEMPUTAN GAGAL", "HINDI NAIPADALA ANG IMBITASYON", "Η ΠΡΟΣΚΛΗΣΗ ΑΠΕΤΥΧΕ", "POZVANIE ZLYHALO", "INVITASJON MISLYKTES", "MỜI THẤT BẠI"], // INVITE_FAILED
        ["FAILED", "BAŞARISIZ", "FEHLER", "FALLÓ", "ÉCHEC", "FALHOU", "GAGAL", "ОШИБКА", "FALLITO", "NIEUDANE", "MISLUKT", "НЕВДАЧА", "EȘUAT", "SELHALO", "SIKERTELEN", "MISSLYCKADES", "EPÄONNISTUI", "MISLYKKEDES", "GAGAL", "NABIGO", "ΑΠΕΤΥΧΕ", "ZLYHALO", "MISLYKTES", "THẤT BẠI"], // FAILED
        ["DECLINED", "REDDETTİ", "ABGELEHNT", "RECHAZÓ", "A REFUSÉ", "RECUSOU", "MENOLAK", "ОТКАЗ", "HA RIFIUTATO", "ODRZUCIŁ", "WEIGERDE", "ВІДХИЛИВ", "A REFUZAT", "ODMÍTL", "ELUTASÍTOTTA", "AVBÖJDE", "HYLKÄSI", "AFVISTE", "MENOLAK", "TUMANGGI", "ΑΡΝΗΘΗΚΕ", "ODMIETOL", "AVSLO", "ĐÃ TỪ CHỐI"], // STATUS_DECLINED
        ["EXPIRED", "SÜRESİ DOLDU", "ABGELAUFEN", "CADUCÓ", "A EXPIRÉ", "EXPIROU", "KEDALUWARSA", "ИСТЕКЛО", "SCADUTO", "WYGASŁO", "VERLOPEN", "ЧАС ВИЙШОВ", "EXPIRAT", "VYPRŠELO", "LEJÁRT", "UTGÅNGEN", "VANHENTUI", "UDLØBET", "TAMAT TEMPOH", "NAG-EXPIRE", "ΕΛΗΞΕ", "VYPRŠALO", "UTLØPT", "ĐÃ HẾT HẠN"], // STATUS_EXPIRED
        ["CANCELLED", "İPTAL EDİLDİ", "ABGEBROCHEN", "CANCELADO", "ANNULÉ", "CANCELADO", "DIBATALKAN", "ОТМЕНЕНО", "ANNULLATO", "ANULOWANO", "GEANNULEERD", "СКАСОВАНО", "ANULAT", "ZRUŠENO", "VISSZAVONVA", "AVBRUTEN", "PERUTTU", "ANNULLERET", "DIBATALKAN", "KINANSELA", "ΑΚΥΡΩΘΗΚΕ", "ZRUŠENÉ", "AVBRUTT", "ĐÃ HỦY"], // STATUS_CANCELLED
        ["ACCEPTED", "KABUL ETTİ", "ANGENOMMEN", "ACEPTÓ", "A ACCEPTÉ", "ACEITOU", "MENERIMA", "ПРИНЯТО", "HA ACCETTATO", "PRZYJĄŁ", "ACCEPTEERDE", "ПРИЙНЯВ", "A ACCEPTAT", "PŘIJAL", "ELFOGADTA", "ACCEPTERADE", "HYVÄKSYI", "ACCEPTEREDE", "MENERIMA", "TUMANGGAP", "ΑΠΟΔΕΧΤΗΚΕ", "PRIJAL", "GODTOK", "ĐÃ CHẤP NHẬN"], // STATUS_ACCEPTED
        ["OK", "TAMAM", "OK", "OK", "OK", "OK", "OK", "ОК", "OK", "OK", "OK", "OK", "OK", "OK", "OK", "OK", "OK", "OK", "OK", "OK", "OK", "OK", "OK", "OK"], // OK_BTN
        ["INVITE SENT", "DAVET GÖNDERİLDİ", "EINLADUNG GESENDET", "INVITACIÓN ENVIADA", "INVITATION ENVOYÉE", "CONVITE ENVIADO", "UNDANGAN TERKIRIM", "ПРИГЛАШЕНИЕ ОТПРАВЛЕНО", "INVITO INVIATO", "WYSŁANO ZAPROSZENIE", "UITNODIGING VERSTUURD", "ЗАПРОШЕННЯ НАДІСЛАНО", "INVITAȚIE TRIMISĂ", "POZVÁNÍ ODESLÁNO", "MEGHÍVÁS ELKÜLDVE", "INBJUDAN SKICKAD", "KUTSU LÄHETETTY", "INVITATION SENDT", "JEMPUTAN DIHANTAR", "NAIPADALA ANG IMBITASYON", "Η ΠΡΟΣΚΛΗΣΗ ΣΤΑΛΘΗΚΕ", "POZVANIE ODOSLANÉ", "INVITASJON SENDT", "ĐÃ GỬI LỜI MỜI"], // INVITE_SENT
        ["WAITING FOR REPLY", "YANIT BEKLENİYOR", "WARTE AUF ANTWORT", "ESPERANDO RESPUESTA", "EN ATTENTE", "AGUARDANDO RESPOSTA", "MENUNGGU JAWABAN", "ЖДЁМ ОТВЕТА", "IN ATTESA DI RISPOSTA", "CZEKAM NA ODPOWIEDŹ", "WACHTEN OP ANTWOORD", "ЧЕКАЄМО ВІДПОВІДІ", "AȘTEPT RĂSPUNS", "ČEKÁM NA ODPOVĚĎ", "VÁRAKOZÁS VÁLASZRA", "VÄNTAR PÅ SVAR", "ODOTETAAN VASTAUSTA", "VENTER PÅ SVAR", "MENUNGGU BALASAN", "NAGHIHINTAY NG SAGOT", "ΑΝΑΜΟΝΗ ΑΠΑΝΤΗΣΗΣ", "ČAKÁ SA NA ODPOVEĎ", "VENTER PÅ SVAR", "ĐANG CHỜ TRẢ LỜI"], // WAITING_REPLY
        ["NEW INVITE", "YENİ DAVET", "NEUE EINLADUNG", "NUEVA INVITACIÓN", "NOUVELLE INVITATION", "NOVO CONVITE", "UNDANGAN BARU", "НОВОЕ ПРИГЛАШЕНИЕ", "NUOVO INVITO", "NOWE ZAPROSZENIE", "NIEUWE UITNODIGING", "НОВЕ ЗАПРОШЕННЯ", "INVITAȚIE NOUĂ", "NOVÉ POZVÁNÍ", "ÚJ MEGHÍVÁS", "NY INBJUDAN", "UUSI KUTSU", "NY INVITATION", "JEMPUTAN BAHARU", "BAGONG IMBITASYON", "ΝΕΑ ΠΡΟΣΚΛΗΣΗ", "NOVÉ POZVANIE", "NY INVITASJON", "LỜI MỜI MỚI"], // NEW_INVITE
        [" DID NOT REPLY", " YANIT VERMEDİ", " ANTWORTET NICHT", " NO RESPONDIÓ", " N'A PAS RÉPONDU", " NÃO RESPONDEU", " TIDAK MENJAWAB", " НЕ ОТВЕТИЛ", " NON HA RISPOSTO", " NIE ODPOWIEDZIAŁ", " REAGEERDE NIET", " НЕ ВІДПОВІВ", " NU A RĂSPUNS", " NEODPOVĚDĚL", " NEM VÁLASZOLT", " SVARADE INTE", " EI VASTANNUT", " SVAREDE IKKE", " TIDAK MEMBALAS", " AY HINDI SUMAGOT", " ΔΕΝ ΑΠΑΝΤΗΣΕ", " NEODPOVEDAL", " SVARTE IKKE", " KHÔNG TRẢ LỜI"], // NO_REPLY
        [" LEFT THE GAME", " OYUNDAN ÇIKTI", " IST OFFLINE", " SALIÓ DEL JUEGO", " A QUITTÉ LE JEU", " SAIU DO JOGO", " KELUAR DARI GAME", " ВЫШЕЛ ИЗ ИГРЫ", " HA LASCIATO", " OPUŚCIŁ GRĘ", " VERLIET HET SPEL", " ВИЙШОВ З ГРИ", " A IEȘIT DIN JOC", " OPUSTIL HRU", " KILÉPETT", " LÄMNADE SPELET", " POISTUI PELISTÄ", " FORLOD SPILLET", " KELUAR PERMAINAN", " AY UMALIS", " ΕΦΥΓΕ ΑΠΟ ΤΟ ΠΑΙΧΝΙΔΙ", " OPUSTIL HRU", " FORLOT SPILLET", " ĐÃ RỜI TRẬN"], // LEFT_GAME
        [" CANCELLED THE INVITE", " DAVETİ İPTAL ETTİ", " HAT ABGESAGT", " CANCELÓ", " A ANNULÉ", " CANCELOU O CONVITE", " MEMBATALKAN", " ОТМЕНИЛ ВЫЗОВ", " HA ANNULLATO", " ANULOWAŁ", " ANNULEERDE", " СКАСУВАВ", " A ANULAT", " ZRUŠIL POZVÁNÍ", " VISSZAVONTA", " AVBRÖT INBJUDAN", " PERUI KUTSUN", " ANNULLEREDE", " MEMBATALKAN", " AY NAGKANSELA", " ΑΚΥΡΩΣΕ ΤΗΝ ΠΡΟΣΚΛΗΣΗ", " ZRUŠIL POZVANIE", " AVBRØT INVITASJONEN", " ĐÃ HỦY LỜI MỜI"], // CANCELLED_INVITE
        ["THE INVITE TIMED OUT", "DAVETİN SÜRESİ DOLDU", "EINLADUNG ABGELAUFEN", "LA INVITACIÓN CADUCÓ", "INVITATION EXPIRÉE", "O CONVITE EXPIROU", "UNDANGAN KEDALUWARSA", "ВРЕМЯ ИСТЕКЛО", "L'INVITO È SCADUTO", "ZAPROSZENIE WYGASŁO", "DE UITNODIGING IS VERLOPEN", "ЧАС ЗАПРОШЕННЯ ВИЙШОВ", "INVITAȚIA A EXPIRAT", "POZVÁNÍ VYPRŠELO", "A MEGHÍVÁS LEJÁRT", "INBJUDAN HAR GÅTT UT", "KUTSU VANHENTUI", "INVITATIONEN ER UDLØBET", "JEMPUTAN TAMAT TEMPOH", "NAG-EXPIRE ANG IMBITASYON", "Η ΠΡΟΣΚΛΗΣΗ ΕΛΗΞΕ", "POZVANIE VYPRŠALO", "INVITASJONEN UTLØP", "LỜI MỜI ĐÃ HẾT HẠN"], // INVITE_TIMEOUT
        ["INVITE NO LONGER VALID", "DAVET ARTIK GEÇERLİ DEĞİL", "EINLADUNG UNGÜLTIG", "INVITACIÓN NO VÁLIDA", "INVITATION NON VALIDE", "CONVITE NÃO É MAIS VÁLIDO", "UNDANGAN TIDAK BERLAKU", "ВЫЗОВ НЕДЕЙСТВИТЕЛЕН", "INVITO NON PIÙ VALIDO", "ZAPROSZENIE JUŻ NIEWAŻNE", "UITNODIGING NIET MEER GELDIG", "ЗАПРОШЕННЯ НЕДІЙСНЕ", "INVITAȚIA NU MAI E VALABILĂ", "POZVÁNÍ UŽ NEPLATÍ", "A MEGHÍVÁS MÁR NEM ÉRVÉNYES", "INBJUDAN GÄLLER INTE LÄNGRE", "KUTSU EI OLE ENÄÄ VOIMASSA", "INVITATIONEN GÆLDER IKKE MERE", "JEMPUTAN TIDAK SAH LAGI", "HINDI NA VALID ANG IMBITASYON", "Η ΠΡΟΣΚΛΗΣΗ ΔΕΝ ΙΣΧΥΕΙ ΠΙΑ", "POZVANIE UŽ NEPLATÍ", "INVITASJONEN GJELDER IKKE", "LỜI MỜI KHÔNG CÒN HIỆU LỰC"], // INVITE_INVALID
        ["PLAYER HAS ANOTHER INVITE", "OYUNCUYA BAŞKA DAVET VAR", "SPIELER HAT SCHON EINE", "TIENE OTRA INVITACIÓN", "IL A UNE AUTRE INVITATION", "JÁ TEM OUTRO CONVITE", "PEMAIN PUNYA UNDANGAN LAIN", "У ИГРОКА ДРУГОЙ ВЫЗОВ", "HA GIÀ UN ALTRO INVITO", "GRACZ MA INNE ZAPROSZENIE", "SPELER HEEFT AL EEN UITNODIGING", "У ГРАВЦЯ ІНШЕ ЗАПРОШЕННЯ", "JUCĂTORUL ARE ALTĂ INVITAȚIE", "HRÁČ MÁ JINÉ POZVÁNÍ", "A JÁTÉKOSNAK MÁS MEGHÍVÁSA VAN", "SPELAREN HAR EN ANNAN INBJUDAN", "PELAAJALLA ON TOINEN KUTSU", "SPILLEREN HAR EN ANDEN INVITATION", "PEMAIN ADA JEMPUTAN LAIN", "MAY IBANG IMBITASYON SIYA", "Ο ΠΑΙΚΤΗΣ ΕΧΕΙ ΑΛΛΗ ΠΡΟΣΚΛΗΣΗ", "HRÁČ MÁ INÉ POZVANIE", "SPILLEREN HAR EN ANNEN INVITASJON", "NGƯỜI CHƠI CÓ LỜI MỜI KHÁC"], // TARGET_BUSY
        ["PLAYER IS OFFLINE", "OYUNCU ARTIK ONLİNE DEĞİL", "SPIELER IST OFFLINE", "EL JUGADOR NO ESTÁ", "JOUEUR HORS LIGNE", "JOGADOR ESTÁ OFFLINE", "PEMAIN SEDANG OFFLINE", "ИГРОК НЕ В СЕТИ", "GIOCATORE OFFLINE", "GRACZ JEST OFFLINE", "SPELER IS OFFLINE", "ГРАВЕЦЬ НЕ В МЕРЕЖІ", "JUCĂTORUL E OFFLINE", "HRÁČ JE OFFLINE", "A JÁTÉKOS OFFLINE", "SPELAREN ÄR OFFLINE", "PELAAJA ON OFFLINE", "SPILLEREN ER OFFLINE", "PEMAIN SEDANG OFFLINE", "OFFLINE ANG MANLALARO", "Ο ΠΑΙΚΤΗΣ ΕΙΝΑΙ ΕΚΤΟΣ ΣΥΝΔΕΣΗΣ", "HRÁČ JE OFFLINE", "SPILLEREN ER OFFLINE", "NGƯỜI CHƠI ĐANG OFFLINE"], // TARGET_OFFLINE
        ["MATCH STARTING", "MAÇ BAŞLIYOR", "SPIEL STARTET", "EMPIEZA LA PARTIDA", "LE MATCH COMMENCE", "PARTIDA COMEÇANDO", "LAGA DIMULAI", "МАТЧ НАЧИНАЕТСЯ", "LA PARTITA INIZIA", "GRA SIĘ ZACZYNA", "SPEL BEGINT", "МАТЧ ПОЧИНАЄТЬСЯ", "MECIUL ÎNCEPE", "HRA ZAČÍNÁ", "INDUL A MECCS", "MATCHEN BÖRJAR", "PELI ALKAA", "KAMPEN STARTER", "PERLAWANAN BERMULA", "NAGSISIMULA ANG LARO", "Ο ΑΓΩΝΑΣ ΞΕΚΙΝΑ", "HRA ZAČÍNA", "KAMPEN STARTER", "TRẬN ĐẤU BẮT ĐẦU"], // MATCH_STARTING
        ["SEARCH", "ARA", "SUCHEN", "BUSCAR", "CHERCHER", "BUSCAR", "CARI", "ПОИСК", "CERCA", "SZUKAJ", "ZOEK", "ПОШУК", "CAUTĂ", "HLEDAT", "KERESÉS", "SÖK", "HAE", "SØG", "CARI", "HANAPIN", "ΑΝΑΖΗΤΗΣΗ", "HĽADAŤ", "SØK", "TÌM"], // SEARCH
        ["PLAYER NAME", "OYUNCU ADI", "SPIELERNAME", "NOMBRE", "NOM DU JOUEUR", "NOME DO JOGADOR", "NAMA PEMAIN", "ИМЯ ИГРОКА", "NOME GIOCATORE", "NAZWA GRACZA", "SPELERSNAAM", "ІМ'Я ГРАВЦЯ", "NUME JUCĂTOR", "JMÉNO HRÁČE", "JÁTÉKOSNÉV", "SPELARNAMN", "PELAAJAN NIMI", "SPILLERNAVN", "NAMA PEMAIN", "PANGALAN NG MANLALARO", "ΟΝΟΜΑ ΠΑΙΚΤΗ", "MENO HRÁČA", "SPILLERNAVN", "TÊN NGƯỜI CHƠI"], // SEARCH_HINT
        ["NO MATCHING PLAYER", "EŞLEŞEN OYUNCU YOK", "KEIN TREFFER", "SIN RESULTADOS", "AUCUN RÉSULTAT", "NENHUM RESULTADO", "TIDAK DITEMUKAN", "НИКОГО НЕ НАЙДЕНО", "NESSUN GIOCATORE", "BRAK GRACZY", "GEEN SPELER GEVONDEN", "ГРАВЦЯ НЕ ЗНАЙДЕНО", "NICIUN JUCĂTOR", "ŽÁDNÝ HRÁČ", "NINCS ILYEN JÁTÉKOS", "INGEN SPELARE HITTAD", "EI PELAAJIA", "INGEN SPILLER FUNDET", "TIADA PEMAIN DITEMUI", "WALANG KATUGMA", "ΚΑΝΕΝΑΣ ΠΑΙΚΤΗΣ", "ŽIADNY HRÁČ", "INGEN SPILLER FUNNET", "KHÔNG TÌM THẤY"], // NO_RESULTS
        ["WORLD RANKING", "DÜNYA SIRALAMASI", "WELTRANGLISTE", "RANKING MUNDIAL", "CLASSEMENT MONDIAL", "RANKING MUNDIAL", "PERINGKAT DUNIA", "МИРОВОЙ РЕЙТИНГ", "CLASSIFICA MONDIALE", "RANKING ŚWIATOWY", "WERELDRANGLIJST", "СВІТОВИЙ РЕЙТИНГ", "CLASAMENT MONDIAL", "SVĚTOVÝ ŽEBŘÍČEK", "VILÁGRANGLISTA", "VÄRLDSRANKING", "MAAILMANLISTA", "VERDENSRANGLISTE", "KEDUDUKAN DUNIA", "RANGGO SA MUNDO", "ΠΑΓΚΟΣΜΙΑ ΚΑΤΑΤΑΞΗ", "SVETOVÝ REBRÍČEK", "VERDENSRANGERING", "XẾP HẠNG THẾ GIỚI"], // WORLD_RANKING
        ["NO.", "NO.", "NR.", "N.", "N.", "N.", "NO.", "#", "N.", "NR.", "NR.", "#", "NR.", "Č.", "#", "NR", "NRO", "NR.", "NO.", "BLG.", "ΑΡ.", "Č.", "NR.", "STT"], // NO
        ["PLAYER", "OYUNCU", "SPIELER", "JUGADOR", "JOUEUR", "JOGADOR", "PEMAIN", "ИГРОК", "GIOCATORE", "GRACZ", "SPELER", "ГРАВЕЦЬ", "JUCĂTOR", "HRÁČ", "JÁTÉKOS", "SPELARE", "PELAAJA", "SPILLER", "PEMAIN", "MANLALARO", "ΠΑΙΚΤΗΣ", "HRÁČ", "SPILLER", "NGƯỜI CHƠI"], // PLAYER
        ["RANK", "RÜTBE", "RANG", "RANGO", "RANG", "RANK", "RANK", "РАНГ", "RANGO", "RANGA", "RANG", "РАНГ", "RANG", "HODNOST", "RANG", "RANG", "ARVO", "RANG", "PANGKAT", "RANGGO", "ΒΑΘΜΟΣ", "HODNOSŤ", "RANG", "HẠNG"], // RANK
        ["RP", "RP", "RP", "RP", "RP", "RP", "RP", "RP", "RP", "RP", "RP", "RP", "RP", "RP", "RP", "RP", "RP", "RP", "RP", "RP", "RP", "RP", "RP", "RP"], // RP
        ["LOADING", "YÜKLENİYOR", "LADEN", "CARGANDO", "CHARGEMENT", "CARREGANDO", "MEMUAT", "ЗАГРУЗКА", "CARICAMENTO", "WCZYTYWANIE", "LADEN", "ЗАВАНТАЖЕННЯ", "SE ÎNCARCĂ", "NAČÍTÁNÍ", "BETÖLTÉS", "LADDAR", "LADATAAN", "INDLÆSER", "MEMUATKAN", "NAGLO-LOAD", "ΦΟΡΤΩΣΗ", "NAČÍTAVA SA", "LASTER", "ĐANG TẢI"], // LOADING
        ["YOU: NO.", "SEN: NO.", "DU: NR.", "TÚ: N.", "TOI: N.", "VOCÊ: N.", "KAMU: NO.", "ВЫ: #", "TU: N.", "TY: NR.", "JIJ: NR.", "ВИ: #", "TU: NR.", "TY: Č.", "TE: #", "DU: NR", "SINÄ: NRO", "DIG: NR.", "ANDA: NO.", "IKAW: BLG.", "ΕΣΥ: ΑΡ.", "TY: Č.", "DEG: NR.", "BẠN: #"], // YOU_NO
        ["GUESTS ARE NOT RANKED", "MİSAFİRLER SIRALANMAZ", "GÄSTE OHNE RANG", "LOS INVITADOS NO TIENEN RANGO", "LES INVITÉS NE SONT PAS CLASSÉS", "CONVIDADOS NÃO ENTRAM NO RANKING", "TAMU TIDAK MASUK PERINGKAT", "ГОСТИ НЕ УЧАСТВУЮТ В РЕЙТИНГЕ", "GLI OSPITI NON SONO IN CLASSIFICA", "GOŚCIE NIE SĄ W RANKINGU", "GASTEN STAAN NIET IN DE LIJST", "ГОСТІ НЕ МАЮТЬ РЕЙТИНГУ", "OASPEȚII NU SUNT CLASAȚI", "HOSTÉ NEJSOU V ŽEBŘÍČKU", "A VENDÉGEK NINCSENEK RANGSOROLVA", "GÄSTER RANKAS INTE", "VIERAAT EIVÄT OLE LISTALLA", "GÆSTER ER IKKE PÅ RANGLISTEN", "TETAMU TIDAK DISENARAIKAN", "WALANG RANGGO ANG MGA BISITA", "ΟΙ ΕΠΙΣΚΕΠΤΕΣ ΔΕΝ ΚΑΤΑΤΑΣΣΟΝΤΑΙ", "HOSTIA NIE SÚ V REBRÍČKU", "GJESTER BLIR IKKE RANGERT", "KHÁCH KHÔNG ĐƯỢC XẾP HẠNG"], // GUESTS_NOT_RANKED
        ["SETTINGS", "AYARLAR", "EINSTELLUNGEN", "AJUSTES", "RÉGLAGES", "AJUSTES", "PENGATURAN", "НАСТРОЙКИ", "IMPOSTAZIONI", "USTAWIENIA", "INSTELLINGEN", "НАЛАШТУВАННЯ", "SETĂRI", "NASTAVENÍ", "BEÁLLÍTÁSOK", "INSTÄLLNINGAR", "ASETUKSET", "INDSTILLINGER", "TETAPAN", "SETTINGS", "ΡΥΘΜΙΣΕΙΣ", "NASTAVENIA", "INNSTILLINGER", "CÀI ĐẶT"], // MENU_SETTINGS
        ["MUSIC", "MÜZİK", "MUSIK", "MÚSICA", "MUSIQUE", "MÚSICA", "MUSIK", "МУЗЫКА", "MUSICA", "MUZYKA", "MUZIEK", "МУЗИКА", "MUZICĂ", "HUDBA", "ZENE", "MUSIK", "MUSIIKKI", "MUSIK", "MUZIK", "MUSIKA", "ΜΟΥΣΙΚΗ", "HUDBA", "MUSIKK", "NHẠC"], // SETTING_MUSIC
        ["ON", "AÇIK", "AN", "SÍ", "OUI", "SIM", "NYALA", "ВКЛ.", "SÌ", "WŁ.", "AAN", "УВІМК.", "DA", "ZAP.", "BE", "PÅ", "PÄÄLLÄ", "TIL", "HIDUP", "BUKAS", "ΝΑΙ", "ZAP.", "PÅ", "BẬT"], // SETTING_ON
        ["OFF", "KAPALI", "AUS", "NO", "NON", "NÃO", "MATI", "ВЫКЛ.", "NO", "WYŁ.", "UIT", "ВИМК.", "NU", "VYP.", "KI", "AV", "POIS", "FRA", "MATI", "SARADO", "ΟΧΙ", "VYP.", "AV", "TẮT"], // SETTING_OFF
        ["ACCOUNT", "HESAP", "KONTO", "CUENTA", "COMPTE", "CONTA", "AKUN", "АККАУНТ", "ACCOUNT", "KONTO", "ACCOUNT", "АКАУНТ", "CONT", "ÚČET", "FIÓK", "KONTO", "TILI", "KONTO", "AKAUN", "ACCOUNT", "ΛΟΓΑΡΙΑΣΜΟΣ", "ÚČET", "KONTO", "TÀI KHOẢN"], // ACCOUNT_TITLE
        ["SIGNED IN AS", "GİRİŞ YAPILDI:", "ANGEMELDET ALS", "SESIÓN INICIADA COMO", "CONNECTÉ EN TANT QUE", "CONECTADO COMO", "MASUK SEBAGAI", "ВЫ ВОШЛИ КАК", "CONNESSO COME", "ZALOGOWANO JAKO", "INGELOGD ALS", "ВИ УВІЙШЛИ ЯК", "CONECTAT CA", "PŘIHLÁŠEN JAKO", "BEJELENTKEZVE:", "INLOGGAD SOM", "KIRJAUTUNUT:", "LOGGET IND SOM", "LOG MASUK SEBAGAI", "NAKA-SIGN IN BILANG", "ΣΥΝΔΕΘΗΚΕΣ ΩΣ", "PRIHLÁSENÝ AKO", "LOGGET INN SOM", "ĐĂNG NHẬP LÀ"], // STATUS_SIGNED_IN
        ["PLAYING AS GUEST", "MİSAFİR OLARAK OYNUYORSUN", "ALS GAST UNTERWEGS", "JUGANDO COMO INVITADO", "TU JOUES EN INVITÉ", "JOGANDO COMO CONVIDADO", "BERMAIN SEBAGAI TAMU", "ВЫ ИГРАЕТЕ КАК ГОСТЬ", "GIOCHI COME OSPITE", "GRASZ JAKO GOŚĆ", "JE SPEELT ALS GAST", "ВИ ГРАЄТЕ ЯК ГІСТЬ", "JOCI CA OASPETE", "HRAJEŠ JAKO HOST", "VENDÉGKÉNT JÁTSZOL", "DU SPELAR SOM GÄST", "PELAAT VIERAANA", "DU SPILLER SOM GÆST", "BERMAIN SEBAGAI TETAMU", "NAGLALARO BILANG BISITA", "ΠΑΙΖΕΙΣ ΩΣ ΕΠΙΣΚΕΠΤΗΣ", "HRÁŠ AKO HOSŤ", "DU SPILLER SOM GJEST", "CHƠI VỚI TƯ CÁCH KHÁCH"], // STATUS_GUEST
        ["NOT SIGNED IN", "GİRİŞ YAPILMADI", "NICHT ANGEMELDET", "SIN INICIAR SESIÓN", "NON CONNECTÉ", "NÃO CONECTADO", "BELUM MASUK", "ВХОД НЕ ВЫПОЛНЕН", "NON CONNESSO", "NIE ZALOGOWANO", "NIET INGELOGD", "ВХІД НЕ ВИКОНАНО", "NECONECTAT", "NEPŘIHLÁŠEN", "NINCS BEJELENTKEZVE", "INTE INLOGGAD", "EI KIRJAUTUNUT", "IKKE LOGGET IND", "BELUM LOG MASUK", "HINDI NAKA-SIGN IN", "ΧΩΡΙΣ ΣΥΝΔΕΣΗ", "NEPRIHLÁSENÝ", "IKKE LOGGET INN", "CHƯA ĐĂNG NHẬP"], // STATUS_NONE
        ["PLAY GAMES: RANKED MATCHES,", "PLAY GAMES: SIRALAMALI MAÇ,", "PLAY GAMES: RANGLISTE,", "PLAY GAMES: PARTIDAS CON RANGO,", "PLAY GAMES: MATCHS CLASSÉS,", "PLAY GAMES: PARTIDAS RANQUEADAS,", "PLAY GAMES: LAGA BERPERINGKAT,", "PLAY GAMES: РЕЙТИНГОВЫЕ МАТЧИ,", "PLAY GAMES: PARTITE CLASSIFICATE,", "PLAY GAMES: GRY RANKINGOWE,", "PLAY GAMES: RANKED WEDSTRIJDEN,", "PLAY GAMES: РЕЙТИНГОВІ МАТЧІ,", "PLAY GAMES: MECIURI CLASATE,", "PLAY GAMES: HODNOCENÉ ZÁPASY,", "PLAY GAMES: RANGSOROLT MECCSEK,", "PLAY GAMES: RANKADE MATCHER,", "PLAY GAMES: SIJOITUSPELIT,", "PLAY GAMES: RANGEREDE KAMPE,", "PLAY GAMES: PERLAWANAN BERPANGKAT,", "PLAY GAMES: MAY RANGGONG LARO,", "PLAY GAMES: ΑΓΩΝΕΣ ΚΑΤΑΤΑΞΗΣ,", "PLAY GAMES: HODNOTENÉ ZÁPASY,", "PLAY GAMES: RANGERTE KAMPER,", "PLAY GAMES: TRẬN XẾP HẠNG,"], // EXPLAIN_PGS_1
        ["LEADERBOARD AND ACHIEVEMENTS", "LİDER TABLOSU VE BAŞARIMLAR", "BESTENLISTE UND ERFOLGE", "CLASIFICACIÓN Y LOGROS", "CLASSEMENT ET SUCCÈS", "CLASSIFICAÇÃO E CONQUISTAS", "PAPAN SKOR DAN PENCAPAIAN", "ТАБЛИЦА ЛИДЕРОВ И ДОСТИЖЕНИЯ", "CLASSIFICA E OBIETTIVI", "RANKING I OSIĄGNIĘCIA", "RANGLIJST EN PRESTATIES", "ТАБЛИЦЯ ЛІДЕРІВ І ДОСЯГНЕННЯ", "CLASAMENT ȘI REALIZĂRI", "ŽEBŘÍČEK A ÚSPĚCHY", "RANGLISTA ÉS EREDMÉNYEK", "TOPPLISTA OCH PRESTATIONER", "TULOSLISTA JA SAAVUTUKSET", "RANGLISTE OG BEDRIFTER", "PAPAN MARKAH DAN PENCAPAIAN", "LEADERBOARD AT ACHIEVEMENTS", "ΠΙΝΑΚΑΣ ΚΑΤΑΤΑΞΗΣ ΚΑΙ ΕΠΙΤΕΥΓΜΑΤΑ", "REBRÍČEK A ÚSPECHY", "TOPPLISTE OG PRESTASJONER", "BẢNG XẾP HẠNG VÀ THÀNH TÍCH"], // EXPLAIN_PGS_2
        ["GUEST: PLAY ONLINE, NOT RANKED", "MİSAFİR: ONLİNE OYNAR, SIRALANMAZ", "GAST: ONLINE, ABER OHNE RANG", "INVITADO: JUEGA ONLINE, SIN RANGO", "INVITÉ: EN LIGNE, SANS CLASSEMENT", "CONVIDADO: JOGA ONLINE, SEM RANK", "TAMU: MAIN ONLINE, TANPA PERINGKAT", "ГОСТЬ: ОНЛАЙН, НО БЕЗ РЕЙТИНГА", "OSPITE: GIOCA ONLINE, SENZA RANGO", "GOŚĆ: GRA ONLINE, BEZ RANGI", "GAST: ONLINE SPELEN, ZONDER RANG", "ГІСТЬ: ОНЛАЙН, АЛЕ БЕЗ РЕЙТИНГУ", "OASPETE: JOCI ONLINE, FĂRĂ RANG", "HOST: HRAJE ONLINE, BEZ HODNOCENÍ", "VENDÉG: ONLINE JÁTÉK, RANG NÉLKÜL", "GÄST: SPELA ONLINE, UTAN RANG", "VIERAS: PELAA ONLINE, EI SIJAA", "GÆST: SPIL ONLINE, UDEN RANG", "TETAMU: MAIN ONLINE, TANPA PANGKAT", "BISITA: ONLINE, PERO WALANG RANGGO", "ΕΠΙΣΚΕΠΤΗΣ: ONLINE ΧΩΡΙΣ ΚΑΤΑΤΑΞΗ", "HOSŤ: HRÁ ONLINE, BEZ HODNOTENIA", "GJEST: SPILL ONLINE, UTEN RANGERING", "KHÁCH: CHƠI ONLINE, KHÔNG XẾP HẠNG"], // EXPLAIN_GUEST
        ["SIGN IN WITH PLAY GAMES", "PLAY GAMES İLE GİRİŞ", "MIT PLAY GAMES ANMELDEN", "ENTRAR CON PLAY GAMES", "CONNEXION AVEC PLAY GAMES", "ENTRAR COM PLAY GAMES", "MASUK DENGAN PLAY GAMES", "ВОЙТИ ЧЕРЕЗ PLAY GAMES", "ACCEDI CON PLAY GAMES", "ZALOGUJ PRZEZ PLAY GAMES", "INLOGGEN MET PLAY GAMES", "УВІЙТИ ЧЕРЕЗ PLAY GAMES", "CONECTARE CU PLAY GAMES", "PŘIHLÁSIT PŘES PLAY GAMES", "BELÉPÉS PLAY GAMES-SZEL", "LOGGA IN MED PLAY GAMES", "KIRJAUDU PLAY GAMESILLA", "LOG IND MED PLAY GAMES", "LOG MASUK DENGAN PLAY GAMES", "MAG-SIGN IN SA PLAY GAMES", "ΣΥΝΔΕΣΗ ΜΕ PLAY GAMES", "PRIHLÁSIŤ CEZ PLAY GAMES", "LOGG INN MED PLAY GAMES", "ĐĂNG NHẬP PLAY GAMES"], // BTN_PGS_SIGN_IN
        ["CONTINUE AS GUEST", "MİSAFİR DEVAM ET", "ALS GAST WEITER", "CONTINUAR COMO INVITADO", "CONTINUER EN INVITÉ", "CONTINUAR COMO CONVIDADO", "LANJUT SEBAGAI TAMU", "ПРОДОЛЖИТЬ КАК ГОСТЬ", "CONTINUA COME OSPITE", "KONTYNUUJ JAKO GOŚĆ", "DOORGAAN ALS GAST", "ПРОДОВЖИТИ ЯК ГІСТЬ", "CONTINUĂ CA OASPETE", "POKRAČOVAT JAKO HOST", "FOLYTATÁS VENDÉGKÉNT", "FORTSÄTT SOM GÄST", "JATKA VIERAANA", "FORTSÆT SOM GÆST", "TERUSKAN SEBAGAI TETAMU", "TULOY BILANG BISITA", "ΣΥΝΕΧΕΙΑ ΩΣ ΕΠΙΣΚΕΠΤΗΣ", "POKRAČOVAŤ AKO HOSŤ", "FORTSETT SOM GJEST", "TIẾP TỤC LÀ KHÁCH"], // BTN_GUEST
        ["DELETE ACCOUNT", "HESABI SİL", "KONTO LÖSCHEN", "BORRAR CUENTA", "SUPPRIMER", "EXCLUIR CONTA", "HAPUS AKUN", "УДАЛИТЬ АККАУНТ", "ELIMINA ACCOUNT", "USUŃ KONTO", "ACCOUNT WISSEN", "ВИДАЛИТИ АКАУНТ", "ȘTERGE CONTUL", "SMAZAT ÚČET", "FIÓK TÖRLÉSE", "RADERA KONTO", "POISTA TILI", "SLET KONTO", "PADAM AKAUN", "BURAHIN ACCOUNT", "ΔΙΑΓΡΑΦΗ", "ZMAZAŤ ÚČET", "SLETT KONTO", "XÓA TÀI KHOẢN"], // BTN_DELETE
        ["DELETE ACCOUNT AND ALL DATA?", "HESAP VE TÜM VERİLER SİLİNSİN Mİ?", "KONTO UND ALLE DATEN LÖSCHEN?", "BORRAR CUENTA Y TODOS LOS DATOS?", "SUPPRIMER COMPTE ET DONNÉES?", "EXCLUIR A CONTA E TODOS OS DADOS?", "HAPUS AKUN DAN SEMUA DATA?", "УДАЛИТЬ АККАУНТ И ВСЕ ДАННЫЕ?", "ELIMINARE ACCOUNT E TUTTI I DATI?", "USUNĄĆ KONTO I WSZYSTKIE DANE?", "ACCOUNT EN ALLE GEGEVENS WISSEN?", "ВИДАЛИТИ АКАУНТ І ВСІ ДАНІ?", "ȘTERGI CONTUL ȘI TOATE DATELE?", "SMAZAT ÚČET A VŠECHNA DATA?", "TÖRLÖD A FIÓKOT ÉS AZ ADATOKAT?", "RADERA KONTO OCH ALL DATA?", "POISTA TILI JA KAIKKI TIEDOT?", "SLET KONTO OG ALLE DATA?", "PADAM AKAUN DAN SEMUA DATA?", "BURAHIN ANG ACCOUNT AT DATA?", "ΔΙΑΓΡΑΦΗ ΛΟΓ/ΣΜΟΥ ΚΑΙ ΔΕΔΟΜΕΝΩΝ;", "ZMAZAŤ ÚČET A VŠETKY ÚDAJE?", "SLETTE KONTO OG ALLE DATA?", "XÓA TÀI KHOẢN VÀ MỌI DỮ LIỆU?"], // CONFIRM_DELETE_1
        ["THIS CANNOT BE UNDONE", "BU İŞLEM GERİ ALINAMAZ", "DAS IST ENDGÜLTIG", "NO SE PUEDE DESHACER", "C'EST IRRÉVERSIBLE", "NÃO DÁ PARA DESFAZER", "TIDAK BISA DIBATALKAN", "ЭТО НЕЛЬЗЯ ОТМЕНИТЬ", "NON SI PUÒ ANNULLARE", "TEGO NIE MOŻNA COFNĄĆ", "DIT KAN NIET ONGEDAAN", "ЦЕ НЕ МОЖНА СКАСУВАТИ", "NU SE POATE ANULA", "TO NELZE VRÁTIT", "EZ NEM VONHATÓ VISSZA", "DET GÅR INTE ATT ÅNGRA", "TÄTÄ EI VOI PERUA", "DET KAN IKKE FORTRYDES", "INI TIDAK BOLEH DIBATALKAN", "HINDI ITO MABABAWI", "ΔΕΝ ΜΠΟΡΕΙ ΝΑ ΑΝΑΙΡΕΘΕΙ", "TOTO SA NEDÁ VRÁTIŤ", "DETTE KAN IKKE ANGRES", "KHÔNG THỂ HOÀN TÁC"], // CONFIRM_DELETE_2
        ["YES, DELETE", "EVET, SİL", "JA, LÖSCHEN", "SÍ, BORRAR", "OUI, SUPPRIMER", "SIM, EXCLUIR", "YA, HAPUS", "ДА, УДАЛИТЬ", "SÌ, ELIMINA", "TAK, USUŃ", "JA, WISSEN", "ТАК, ВИДАЛИТИ", "DA, ȘTERGE", "ANO, SMAZAT", "IGEN, TÖRLÉS", "JA, RADERA", "KYLLÄ, POISTA", "JA, SLET", "YA, PADAM", "OO, BURAHIN", "ΝΑΙ, ΔΙΑΓΡΑΦΗ", "ÁNO, ZMAZAŤ", "JA, SLETT", "CÓ, XÓA"], // YES_DELETE
        ["NO", "HAYIR", "NEIN", "NO", "NON", "NÃO", "TIDAK", "НЕТ", "NO", "NIE", "NEE", "НІ", "NU", "NE", "NEM", "NEJ", "EI", "NEJ", "TIDAK", "HINDI", "ΟΧΙ", "NIE", "NEI", "KHÔNG"], // NO_KEEP
        ["ACCOUNT DELETED", "HESAP SİLİNDİ", "KONTO GELÖSCHT", "CUENTA BORRADA", "COMPTE SUPPRIMÉ", "CONTA EXCLUÍDA", "AKUN DIHAPUS", "АККАУНТ УДАЛЁН", "ACCOUNT ELIMINATO", "KONTO USUNIĘTE", "ACCOUNT GEWIST", "АКАУНТ ВИДАЛЕНО", "CONT ȘTERS", "ÚČET SMAZÁN", "FIÓK TÖRÖLVE", "KONTOT RADERAT", "TILI POISTETTU", "KONTO SLETTET", "AKAUN DIPADAM", "NABURA ANG ACCOUNT", "Ο ΛΟΓΑΡΙΑΣΜΟΣ ΔΙΑΓΡΑΦΗΚΕ", "ÚČET ZMAZANÝ", "KONTO SLETTET", "ĐÃ XÓA TÀI KHOẢN"], // DELETED
        ["DELETING", "SİLİNİYOR", "LÖSCHEN", "BORRANDO", "SUPPRESSION", "EXCLUINDO", "MENGHAPUS", "УДАЛЕНИЕ", "ELIMINAZIONE", "USUWANIE", "WISSEN", "ВИДАЛЕННЯ", "SE ȘTERGE", "MAZÁNÍ", "TÖRLÉS", "RADERAR", "POISTETAAN", "SLETTER", "MEMADAM", "BINUBURA", "ΔΙΑΓΡΑΦΗ", "MAZANIE", "SLETTER", "ĐANG XÓA"], // DELETING
        ["PLAY GAMES NOT AVAILABLE HERE", "PLAY GAMES BURADA KULLANILAMIYOR", "PLAY GAMES HIER NICHT VERFÜGBAR", "PLAY GAMES NO DISPONIBLE AQUÍ", "PLAY GAMES INDISPONIBLE ICI", "PLAY GAMES INDISPONÍVEL AQUI", "PLAY GAMES TIDAK TERSEDIA", "PLAY GAMES ЗДЕСЬ НЕДОСТУПЕН", "PLAY GAMES NON DISPONIBILE QUI", "PLAY GAMES TU NIEDOSTĘPNE", "PLAY GAMES HIER NIET BESCHIKBAAR", "PLAY GAMES ТУТ НЕДОСТУПНИЙ", "PLAY GAMES INDISPONIBIL AICI", "PLAY GAMES ZDE NENÍ K DISPOZICI", "A PLAY GAMES ITT NEM ÉRHETŐ EL", "PLAY GAMES FINNS INTE HÄR", "PLAY GAMES EI OLE KÄYTÖSSÄ TÄÄLLÄ", "PLAY GAMES FINDES IKKE HER", "PLAY GAMES TIADA DI SINI", "WALANG PLAY GAMES DITO", "ΤΟ PLAY GAMES ΔΕΝ ΕΙΝΑΙ ΔΙΑΘΕΣΙΜΟ", "PLAY GAMES TU NIE JE DOSTUPNÉ", "PLAY GAMES ER IKKE TILGJENGELIG", "PLAY GAMES KHÔNG KHẢ DỤNG"], // PGS_UNAVAILABLE
        ["PLAY GAMES NOT SET UP YET", "PLAY GAMES HENÜZ AYARLANMADI", "PLAY GAMES NICHT EINGERICHTET", "PLAY GAMES AÚN NO CONFIGURADO", "PLAY GAMES PAS ENCORE PRÊT", "PLAY GAMES NÃO CONFIGURADO", "PLAY GAMES BELUM DISIAPKAN", "PLAY GAMES ЕЩЁ НЕ НАСТРОЕН", "PLAY GAMES NON ANCORA PRONTO", "PLAY GAMES JESZCZE NIEGOTOWE", "PLAY GAMES NOG NIET INGESTELD", "PLAY GAMES ЩЕ НЕ НАЛАШТОВАНО", "PLAY GAMES NU E CONFIGURAT", "PLAY GAMES ZATÍM NENÍ NASTAVENO", "A PLAY GAMES MÉG NINCS BEÁLLÍTVA", "PLAY GAMES ÄR INTE KLART ÄN", "PLAY GAMES EI OLE VIELÄ VALMIS", "PLAY GAMES ER IKKE KLAR ENDNU", "PLAY GAMES BELUM DISEDIAKAN", "HINDI PA HANDA ANG PLAY GAMES", "ΤΟ PLAY GAMES ΔΕΝ ΡΥΘΜΙΣΤΗΚΕ ΑΚΟΜΑ", "PLAY GAMES ZATIAĽ NIE JE NASTAVENÉ", "PLAY GAMES ER IKKE KLAR ENNÅ", "PLAY GAMES CHƯA ĐƯỢC THIẾT LẬP"], // PGS_NOT_CONFIGURED
        ["PLAY GAMES SIGN IN FAILED", "PLAY GAMES GİRİŞİ YAPILAMADI", "PLAY-GAMES-ANMELDUNG FEHLER", "FALLÓ EL INICIO EN PLAY GAMES", "ÉCHEC CONNEXION PLAY GAMES", "FALHA AO ENTRAR NO PLAY GAMES", "GAGAL MASUK PLAY GAMES", "НЕ УДАЛОСЬ ВОЙТИ В PLAY GAMES", "ACCESSO PLAY GAMES FALLITO", "BŁĄD LOGOWANIA PLAY GAMES", "INLOGGEN PLAY GAMES MISLUKT", "НЕ ВДАЛОСЯ УВІЙТИ В PLAY GAMES", "CONECTARE PLAY GAMES EȘUATĂ", "PŘIHLÁŠENÍ PLAY GAMES SELHALO", "PLAY GAMES BELÉPÉS SIKERTELEN", "INLOGGNING I PLAY GAMES MISSLYCKADES", "PLAY GAMES -KIRJAUTUMINEN EPÄONNISTUI", "LOGIN I PLAY GAMES MISLYKKEDES", "GAGAL LOG MASUK PLAY GAMES", "HINDI NAKA-SIGN IN SA PLAY GAMES", "ΑΠΟΤΥΧΙΑ ΣΥΝΔΕΣΗΣ PLAY GAMES", "PRIHLÁSENIE DO PLAY GAMES ZLYHALO", "INNLOGGING I PLAY GAMES MISLYKTES", "ĐĂNG NHẬP PLAY GAMES THẤT BẠI"], // PGS_SIGN_IN_FAILED
        ["PLAY GAMES SERVER ACCESS DENIED", "PLAY GAMES SUNUCU İZNİ YOK", "PLAY GAMES SERVERZUGRIFF FEHLT", "PLAY GAMES: ACCESO DENEGADO", "PLAY GAMES: ACCÈS REFUSÉ", "PLAY GAMES: ACESSO NEGADO", "PLAY GAMES: AKSES DITOLAK", "PLAY GAMES: ДОСТУП ЗАПРЕЩЁН", "PLAY GAMES: ACCESSO NEGATO", "PLAY GAMES: BRAK DOSTĘPU", "PLAY GAMES: GEEN TOEGANG", "PLAY GAMES: ДОСТУП ЗАБОРОНЕНО", "PLAY GAMES: ACCES REFUZAT", "PLAY GAMES: PŘÍSTUP ODEPŘEN", "PLAY GAMES: HOZZÁFÉRÉS MEGTAGADVA", "PLAY GAMES: ÅTKOMST NEKAD", "PLAY GAMES: PÄÄSY ESTETTY", "PLAY GAMES: ADGANG NÆGTET", "PLAY GAMES: AKSES DITOLAK", "PLAY GAMES: TINANGGIHAN", "PLAY GAMES: ΑΡΝΗΣΗ ΠΡΟΣΒΑΣΗΣ", "PLAY GAMES: PRÍSTUP ODOPRETÝ", "PLAY GAMES: TILGANG NEKTET", "PLAY GAMES: TỪ CHỐI TRUY CẬP"], // PGS_SERVER_ACCESS
        ["SIGNED IN", "GİRİŞ YAPILDI", "ANGEMELDET", "SESIÓN INICIADA", "CONNECTÉ", "CONECTADO", "BERHASIL MASUK", "ВХОД ВЫПОЛНЕН", "CONNESSO", "ZALOGOWANO", "INGELOGD", "ВХІД ВИКОНАНО", "CONECTAT", "PŘIHLÁŠENO", "BEJELENTKEZVE", "INLOGGAD", "KIRJAUTUNUT", "LOGGET IND", "BERJAYA LOG MASUK", "NAKA-SIGN IN", "ΣΥΝΔΕΘΗΚΕΣ", "PRIHLÁSENÉ", "LOGGET INN", "ĐÃ ĐĂNG NHẬP"], // SIGNED_IN_OK
        ["CHOOSE ACCOUNT", "HESAP SEÇ", "KONTO WÄHLEN", "ELIGE CUENTA", "CHOISIS UN COMPTE", "ESCOLHA A CONTA", "PILIH AKUN", "ВЫБОР АККАУНТА", "SCEGLI ACCOUNT", "WYBIERZ KONTO", "KIES ACCOUNT", "ВИБІР АКАУНТА", "ALEGE CONTUL", "VYBER ÚČET", "VÁLASSZ FIÓKOT", "VÄLJ KONTO", "VALITSE TILI", "VÆLG KONTO", "PILIH AKAUN", "PUMILI NG ACCOUNT", "ΕΠΙΛΟΓΗ ΛΟΓΑΡΙΑΣΜΟΥ", "VYBER SI ÚČET", "VELG KONTO", "CHỌN TÀI KHOẢN"], // SETUP_TITLE
        ["YOU CHOOSE THIS ONLY ONCE", "BU SEÇİM BİR KEZ YAPILIR", "DU WÄHLST NUR EINMAL", "SOLO ELIGES UNA VEZ", "TU CHOISIS UNE SEULE FOIS", "VOCÊ ESCOLHE SÓ UMA VEZ", "HANYA DIPILIH SEKALI", "ВЫБОР ДЕЛАЕТСЯ ОДИН РАЗ", "LO SCEGLI UNA SOLA VOLTA", "WYBIERASZ TYLKO RAZ", "JE KIEST DIT MAAR EEN KEER", "ВИБІР РОБИТЬСЯ ОДИН РАЗ", "ALEGI ASTA O SINGURĂ DATĂ", "VYBÍRÁŠ JEN JEDNOU", "EZT CSAK EGYSZER VÁLASZTOD", "DU VÄLJER DETTA BARA EN GÅNG", "VALITSET TÄMÄN VAIN KERRAN", "DU VÆLGER KUN ÉN GANG", "ANDA PILIH INI SEKALI SAHAJA", "ISANG BESES LANG ITO PIPILIIN", "ΤΟ ΕΠΙΛΕΓΕΙΣ ΜΟΝΟ ΜΙΑ ΦΟΡΑ", "VYBERÁŠ IBA RAZ", "DU VELGER DETTE BARE ÉN GANG", "BẠN CHỈ CHỌN MỘT LẦN"], // SETUP_ONCE
        ["PLAY OFFLINE", "ÇEVRİMDIŞI OYNA", "OFFLINE SPIELEN", "JUGAR SIN RED", "JOUER HORS LIGNE", "JOGAR OFFLINE", "MAIN OFFLINE", "ИГРАТЬ ОФЛАЙН", "GIOCA OFFLINE", "GRAJ OFFLINE", "OFFLINE SPELEN", "ГРАТИ ОФЛАЙН", "JOACĂ OFFLINE", "HRÁT OFFLINE", "OFFLINE JÁTÉK", "SPELA OFFLINE", "PELAA OFFLINE", "SPIL OFFLINE", "MAIN OFFLINE", "MAGLARO OFFLINE", "ΠΑΙΞΕ OFFLINE", "HRAŤ OFFLINE", "SPILL OFFLINE", "CHƠI OFFLINE"], // PLAY_OFFLINE
        ["MY RANKING", "SIRALAMAM", "MEIN RANG", "MI RANGO", "MON RANG", "MEU RANKING", "PERINGKATKU", "МОЙ РЕЙТИНГ", "IL MIO RANGO", "MOJA RANGA", "MIJN RANG", "МІЙ РЕЙТИНГ", "RANGUL MEU", "MOJE POŘADÍ", "HELYEZÉSEM", "MIN RANKING", "SIJOITUKSENI", "MIN PLACERING", "KEDUDUKAN SAYA", "ANG RANGGO KO", "Η ΚΑΤΑΤΑΞΗ ΜΟΥ", "MOJE PORADIE", "MIN RANGERING", "HẠNG CỦA TÔI"], // MY_RANKING
        ["BRONZE", "BRONZ", "BRONZE", "BRONCE", "BRONZE", "BRONZE", "PERUNGGU", "БРОНЗА", "BRONZO", "BRĄZ", "BRONS", "БРОНЗА", "BRONZ", "BRONZ", "BRONZ", "BRONS", "PRONSSI", "BRONZE", "GANGSA", "TANSO", "ΧΑΛΚΟΣ", "BRONZ", "BRONSE", "ĐỒNG"], // RANK_BRONZE
        ["SILVER", "GÜMÜŞ", "SILBER", "PLATA", "ARGENT", "PRATA", "PERAK", "СЕРЕБРО", "ARGENTO", "SREBRO", "ZILVER", "СРІБЛО", "ARGINT", "STŘÍBRO", "EZÜST", "SILVER", "HOPEA", "SØLV", "PERAK", "PILAK", "ΑΣΗΜΙ", "STRIEBRO", "SØLV", "BẠC"], // RANK_SILVER
        ["GOLD", "ALTIN", "GOLD", "ORO", "OR", "OURO", "EMAS", "ЗОЛОТО", "ORO", "ZŁOTO", "GOUD", "ЗОЛОТО", "AUR", "ZLATO", "ARANY", "GULD", "KULTA", "GULD", "EMAS", "GINTO", "ΧΡΥΣΟΣ", "ZLATO", "GULL", "VÀNG"], // RANK_GOLD
        ["PLATINUM", "PLATİN", "PLATIN", "PLATINO", "PLATINE", "PLATINA", "PLATINUM", "ПЛАТИНА", "PLATINO", "PLATYNA", "PLATINA", "ПЛАТИНА", "PLATINĂ", "PLATINA", "PLATINA", "PLATINA", "PLATINA", "PLATIN", "PLATINUM", "PLATINUM", "ΠΛΑΤΙΝΑ", "PLATINA", "PLATINA", "BẠCH KIM"], // RANK_PLATINUM
        ["DIAMOND", "ELMAS", "DIAMANT", "DIAMANTE", "DIAMANT", "DIAMANTE", "BERLIAN", "АЛМАЗ", "DIAMANTE", "DIAMENT", "DIAMANT", "ДІАМАНТ", "DIAMANT", "DIAMANT", "GYÉMÁNT", "DIAMANT", "TIMANTTI", "DIAMANT", "BERLIAN", "DIYAMANTE", "ΔΙΑΜΑΝΤΙ", "DIAMANT", "DIAMANT", "KIM CƯƠNG"], // RANK_DIAMOND
        ["MASTER", "USTA", "MEISTER", "MAESTRO", "MAÎTRE", "MESTRE", "MASTER", "МАСТЕР", "MAESTRO", "MISTRZ", "MEESTER", "МАЙСТЕР", "MAESTRU", "MISTR", "MESTER", "MÄSTARE", "MESTARI", "MESTER", "PAKAR", "MAESTRO", "ΜΑΕΣΤΡΟΣ", "MAJSTER", "MESTER", "CAO THỦ"], // RANK_MASTER
    ]
}
