import Foundation

/// Every sentence the user sees or hears, in Hong Kong written Cantonese.
/// Keep wording here, not in views, so a nurse or dietitian can review it in one place.
/// The speech voice reads these exactly as written.
enum Str {
    // App
    static let appName = "健康伴你行"

    // Home
    static let homeGreeting = "你好！今日想做啲乜呀？"
    static let homeSpoken = "你好！今日想做啲乜呀？按食物、心情，或者求助。"

    static let food = "食物"
    static let foodHint = "睇下食物健唔健康"
    static let mood = "心情"
    static let moodHint = "話畀我知你今日點呀"
    static let help = "求助"
    static let helpHint = "打電話搵人幫手"
    static let settings = "設定"

    // Placeholders for features arriving in later phases
    static let moodSpoken = "你可以記錄心情、做呼吸練習、同我傾偈，或者睇今個星期。"
    static let comingSoon = "呢個功能好快會有。"

    // Help
    static let helpTitle = "打電話求助"
    static let helpSpokenWithContacts = "按你想打畀嘅人。"
    static let helpSpokenNoContacts = "仲未有緊急聯絡人。請職員幫你喺設定入面加。"
    static let helpNoContacts = "仲未有緊急聯絡人。\n請職員幫你喺「設定」入面加。"
    static func callConfirmTitle(_ name: String) -> String { "打電話畀\(name)？" }
    static let callConfirmYes = "打電話"
    static let cancel = "取消"

    // Settings
    static let settingsTitle = "設定"
    static let settingsSpoken = "呢度可以調較字體同埋聲音。"
    static let textSize = "字體大細"
    static let textSizeSample = "字體大細示範"
    static let highContrast = "高對比顏色"
    static let voiceSection = "聲音"
    static let speechEnabled = "自動讀出畫面內容"
    static let speechRate = "讀出速度"
    static let slow = "慢"
    static let fast = "快"
    static let testVoice = "試聽"
    static let testVoiceSpoken = "你好，呢個係我讀出嚟嘅聲音。"
    static let contactsSection = "緊急聯絡人"
    static let addContact = "新增聯絡人"
    static let contactName = "姓名"
    static let contactPhone = "電話號碼"
    static let save = "儲存"
    static let delete = "刪除"
    static let staffNote = "建議由職員幫手設定。"

    // Food hub
    static let foodSpoken = "你可以掃描條碼，或者影包裝上嘅營養標籤。"
    static let scanBarcode = "掃描條碼"
    static let scanBarcodeHint = "對正包裝上嘅條碼"
    static let scanLabel = "影營養標籤"
    static let scanLabelHint = "影包裝上嘅營養資料"
    static let mealPhoto = "影整餐嘢"
    static let mealPhotoHint = "影張相，或者喺清單揀"

    // Barcode scan
    static let barcodeTitle = "掃描條碼"
    static let barcodePrompt = "將條碼對正鏡頭"
    static let barcodeSpoken = "請將條碼放喺鏡頭前面，慢慢移近。"
    static let barcodeLooking = "等一等，我幫你查緊。"
    static let barcodeNotFound = "搵唔到呢樣產品嘅資料。請影包裝上嘅營養標籤。"
    static let barcodeOffline = "上唔到網。請影包裝上嘅營養標籤。"
    static let scanAgain = "再掃描一次"
    static let typeBarcode = "或者輸入條碼數字"
    static let barcodeField = "條碼數字"
    static let lookUp = "查詢"
    static let scannerUnavailable = "呢部電話暫時用唔到相機掃描。請檢查相機權限，或者輸入條碼數字。"

    // Label scan
    static let labelTitle = "影營養標籤"
    static let labelSpoken = "請將營養標籤放入畫面，保持光猛，然後按影相掣。"
    static let takePhoto = "影相"
    static let pickPhoto = "揀相簿入面嘅相"
    static let labelReading = "等一等，我睇緊個標籤。"
    static let labelUnreadable = "睇唔清楚個標籤。請行近啲、光線光啲，再影一次。"

    // Result
    static let resultTitle = "結果"
    static let resultLabelName = "營養標籤"
    static let sugarName = "糖"
    static let sodiumName = "鈉"
    static let otherFacts = "其他資料"
    static let energyName = "能量"
    static let proteinName = "蛋白質"
    static let fatName = "總脂肪"
    static let satFatName = "飽和脂肪"
    static let transFatName = "反式脂肪"
    static let carbsName = "碳水化合物"
    static let unitG = "克"
    static let unitMg = "毫克"
    static let unitKcal = "千卡"
    static let per100g = "每100克"
    static let per100ml = "每100毫升"
    static let perServing = "每份"
    static let levelLow = "偏低"
    static let levelMid = "中等"
    static let levelHigh = "偏高"
    static let savedNote = "已儲存喺電話入面"

    // Result wording. A nurse or dietitian must approve these before real use.
    static let tipHigher = "整體偏高，可以食少啲，或者揀細份啲。"
    static let tipMiddle = "整體中等，適量就得。"
    static let tipLower = "整體偏低。"
    static let carbsNote = "碳水化合物未有評級，請問職員或營養師。"
    static let checkPackage = "呢個只係參考，請同包裝上嘅數字核對。"
    static let perServingNote = "呢個標籤係按每份計算，我暫時未能夠評級。請職員幫你睇。"
    static let unratedNote = "我睇唔清楚呢個標籤嘅糖同鈉。請再影一次，或者請職員幫你。"

    // Mood hub
    static let moodCheck = "今日心情"
    static let moodCheckHint = "話畀我知你今日點"
    static let breathing = "呼吸練習"
    static let breathingHint = "慢慢吸氣，慢慢呼氣"
    static let chat = "同我傾偈"
    static let chatHint = "電腦助手陪你傾"
    static let week = "今個星期"
    static let weekHint = "睇下食物同心情"

    // Mood check
    static let moodCheckTitle = "今日心情"
    static let moodCheckSpoken = "你今日覺得點呀？按一個掣。"
    static let moodOkay = "幾好"
    static let moodOkayHint = "今日精神唔錯"
    static let moodLonely = "有啲寂寞"
    static let moodLonelyHint = "想有人陪下"
    static let moodNotWell = "唔係幾好"
    static let moodNotWellHint = "覺得唔舒服或者唔開心"
    static let moodAnswerOkay = "好呀！聽到你幾好，我都開心。"
    static let moodAnswerLonely = "多謝你話畀我知。想唔想做個呼吸練習，或者同我傾下偈？"
    static let moodAnswerNotWell = "聽到你唔係幾好，我好關心你。想唔想搵人傾下？"
    static let moodAnswerPattern = "我留意到你呢幾日都唔係幾好。你想搵邊個傾下？"
    static let moodSaved = "已經記低咗"
    static let callSomeone = "搵人傾下"
    static let callSomeoneHint = "打電話畀你信任嘅人"
    static let done = "完成"

    static func moodWord(_ level: Int) -> String {
        switch level {
        case 0: return "幾好"
        case 1: return "有啲寂寞"
        default: return "唔係幾好"
        }
    }

    // Breathing
    static let breathingTitle = "呼吸練習"
    static let breathingSpoken = "揀兩分鐘或者三分鐘，我會陪你慢慢呼吸。"
    static let twoMinutes = "兩分鐘"
    static let threeMinutes = "三分鐘"
    static let minutesHint = "跟住我慢慢做"
    static let breathingIntro = "坐舒服啲，放鬆肩膊。跟住我慢慢吸氣，慢慢呼氣。"
    static let breatheIn = "吸氣"
    static let breatheOut = "呼氣"
    static let breathingDone = "做得好。多謝你。"
    static let stop = "停止"
    static func secondsLeft(_ seconds: Int) -> String { "仲有\(seconds)秒" }

    // Call screen
    static let callTitle = "打電話求助"
    static let callPromptHelp = "你想搵邊個？按住個掣，直至滿晒，就會打出去。"
    static let callPromptDistress = "我知你而家唔係幾好。你想搵邊個傾下？按住個掣，就會打出去。"
    static let callPromptMedical = "如果好緊急，按住緊急服務個掣。第啲人都可以按住掣打電話。"
    static let holdHint = "按住個掣，直至滿晒，先會打出去。"
    static let sendMessage = "發訊息"
    static let alertMessageBody = "我而家唔係幾好，可以打畀我或者嚟睇下我嗎？"
    static let imOkay = "我冇事，返回"
    static let close = "閂返"
    static let emergencyName = "緊急服務"
    static let haMentalHealthName = "醫管局精神健康專線"
    static let befriendersName = "撒瑪利亞防止自殺會"
    static let spsName = "防止自殺服務處"

    // Chat
    static let chatTitle = "同我傾偈"
    static let chatBanner = "我係電腦助手，唔係真人、醫生或者危機熱線。"
    static let chatWelcome = "你好！我係電腦助手。你可以同我傾下今日嘅心情，或者按「今日小提示」。"
    static let chatPlaceholder = "喺度打字"
    static let send = "傳送"
    static let chatListening = "我聽緊："
    static let micHint = "按咪高風，講嘢"
    static let micDenied = "未可以用咪高風。請去「設定」開啟，或者用打字。"
    static let tipChip = "今日小提示"
    static let tipPrompt = "請根據我今日嘅記錄，講一句簡單嘅小提示。"
    static let chatUrgentReply = "我聽到你而家好辛苦，我好擔心你。請搵人傾下，我幫你打開求助畫面。"
    static let chatMedicationReply = "藥物嘅問題要問醫生或者護士，我答唔到。"
    static let chatDiagnosisReply = "我唔可以診斷。如果你擔心，可以同護士或者醫生傾下。"
    static let chatUnavailable = "聊天功能暫時未開通。你可以按「求助」搵人傾下。"
    static let chatOffline = "我暫時連唔到網絡。你可以按「求助」搵人傾下。"
    static let chatLimitReply = "今日傾得夠多喇，聽日再傾啦。"
    static let chatSafeFallback = "呢個問題我答唔到。你可以問下你嘅護士或者醫生。"
    static let chatSupportButton = "搵人傾下"

    // Tips (fixed fallback wording; a nurse or dietitian must approve)
    static let tipHighFood = "今日有食物糖或者鈉偏高，下一餐可以揀清淡啲。"
    static let tipLonely = "同家人或者朋友傾下偈，打個電話都得。"
    static let tipGeneral1 = "食嘢慢慢食，唔使急。"
    static let tipGeneral2 = "天氣好嘅時候，喺屋企附近慢慢行幾步，量力而為。"
    static let tipGeneral3 = "食嘢之前，睇下標籤上面嘅糖同鈉。"

    // Week
    static let weekTitle = "今個星期"
    static let weekEmpty = "呢個星期仲未有記錄。"
    static func weekSpoken(moodDays: Int, meals: Int, higher: Int) -> String {
        var text = "今個星期，你記錄咗\(moodDays)日心情、\(meals)樣食物"
        if higher > 0 { text += "，其中\(higher)樣糖或鈉偏高" }
        return text + "。"
    }
    static let today = "今日"
    static let yesterday = "琴日"
    static let noMood = "未記錄心情"
    static let noMeals = "未記錄食物"
    static func mealsCount(_ count: Int) -> String { "食物 \(count) 樣" }
    static let highFoodNote = "糖或鈉偏高"

    // Share and demo
    static let shareButton = "分享今個星期"
    static let shareNote = "只會分享次數同心情，唔會有產品名。由你揀分享畀邊個。"
    static let shareHeader = "健康伴你行：今個星期記錄"
    static func shareAlerts(_ count: Int) -> String { "今個星期求助或提醒 \(count) 次" }
    static let shareFooter = "呢份記錄只係參考，唔係診斷。"
    static let demoSection = "示範資料"
    static let demoFooter = "示範用嘅虛構記錄，唔係真人資料。清除只會刪走示範記錄。"
    static let demoLoad = "加入示範資料"
    static let demoClear = "清除示範資料"
    static let demoLoaded = "已加入示範資料。"
    static let demoCleared = "已清除示範資料。"

    // Shared
    static let readAloud = "讀出嚟"
    static let back = "返回"
    static let noCantoneseVoice = "呢部電話未安裝粵語聲音。請去「設定 > 輔助使用 > 朗讀內容 > 聲音」下載。"
}
