import Foundation

enum StyledSpeech {
    private struct Replacement {
        let source: String
        let target: String
    }

    private static let britishReplacements = [
        Replacement(source: "apartment", target: "flat"),
        Replacement(source: "attorney", target: "solicitor"),
        Replacement(source: "awesome", target: "brilliant"),
        Replacement(source: "baby stroller", target: "pram"),
        Replacement(source: "bathroom", target: "loo"),
        Replacement(source: "canceled", target: "cancelled"),
        Replacement(source: "canceling", target: "cancelling"),
        Replacement(source: "candy", target: "sweets"),
        Replacement(source: "cell phone", target: "mobile"),
        Replacement(source: "closet", target: "wardrobe"),
        Replacement(source: "color", target: "colour"),
        Replacement(source: "cookie", target: "biscuit"),
        Replacement(source: "diaper", target: "nappy"),
        Replacement(source: "elevator", target: "lift"),
        Replacement(source: "eraser", target: "rubber"),
        Replacement(source: "favorite", target: "favourite"),
        Replacement(source: "faucet", target: "tap"),
        Replacement(source: "flashlight", target: "torch"),
        Replacement(source: "fries", target: "chips"),
        Replacement(source: "garbage", target: "rubbish"),
        Replacement(source: "gas", target: "petrol"),
        Replacement(source: "gotten", target: "got"),
        Replacement(source: "hood", target: "bonnet"),
        Replacement(source: "line", target: "queue"),
        Replacement(source: "mail", target: "post"),
        Replacement(source: "math", target: "maths"),
        Replacement(source: "mom", target: "mum"),
        Replacement(source: "movie", target: "film"),
        Replacement(source: "pants", target: "trousers"),
        Replacement(source: "parking lot", target: "car park"),
        Replacement(source: "potato chips", target: "crisps"),
        Replacement(source: "restroom", target: "loo"),
        Replacement(source: "schedule", target: "timetable"),
        Replacement(source: "sidewalk", target: "pavement"),
        Replacement(source: "soccer", target: "football"),
        Replacement(source: "sneakers", target: "trainers"),
        Replacement(source: "store", target: "shop"),
        Replacement(source: "stroller", target: "pram"),
        Replacement(source: "subway", target: "underground"),
        Replacement(source: "sweater", target: "jumper"),
        Replacement(source: "takeout", target: "takeaway"),
        Replacement(source: "trash", target: "rubbish"),
        Replacement(source: "truck", target: "lorry"),
        Replacement(source: "trunk", target: "boot"),
        Replacement(source: "vacation", target: "holiday"),
        Replacement(source: "wrench", target: "spanner"),
        Replacement(source: "yard", target: "garden"),
        Replacement(source: "yeah", target: "yes"),
        Replacement(source: "yep", target: "yes"),
        Replacement(source: "zip code", target: "postcode")
    ]

    private static let genZReplacements = [
        Replacement(source: "absolutely not", target: "hard pass"),
        Replacement(source: "are you serious", target: "are you fr"),
        Replacement(source: "as soon as possible", target: "asap"),
        Replacement(source: "a big deal", target: "major"),
        Replacement(source: "a lot", target: "a ton"),
        Replacement(source: "all right", target: "bet"),
        Replacement(source: "bad idea", target: "not the move"),
        Replacement(source: "calm down", target: "chill"),
        Replacement(source: "can you", target: "could you"),
        Replacement(source: "can we", target: "could we"),
        Replacement(source: "check why", target: "figure out why"),
        Replacement(source: "does not work", target: "is not working"),
        Replacement(source: "doesn't work", target: "is not working"),
        Replacement(source: "do you understand", target: "does that track"),
        Replacement(source: "do you want to", target: "are you down to"),
        Replacement(source: "for real", target: "fr"),
        Replacement(source: "good idea", target: "the move"),
        Replacement(source: "help me", target: "help me out"),
        Replacement(source: "i agree", target: "valid"),
        Replacement(source: "i am excited", target: "i'm hyped"),
        Replacement(source: "i do not know", target: "idk"),
        Replacement(source: "i don't know", target: "idk"),
        Replacement(source: "i guess", target: "i feel like"),
        Replacement(source: "i like it", target: "it hits"),
        Replacement(source: "i think", target: "i feel like"),
        Replacement(source: "let me know", target: "lmk"),
        Replacement(source: "look into this", target: "check this out"),
        Replacement(source: "makes sense", target: "tracks"),
        Replacement(source: "no problem", target: "all good"),
        Replacement(source: "not good", target: "not it"),
        Replacement(source: "not working", target: "broken"),
        Replacement(source: "okay", target: "bet"),
        Replacement(source: "ok", target: "bet"),
        Replacement(source: "right now", target: "rn"),
        Replacement(source: "sounds good", target: "sounds solid"),
        Replacement(source: "thank you", target: "ty"),
        Replacement(source: "that is amazing", target: "that goes hard"),
        Replacement(source: "that is annoying", target: "that's rough"),
        Replacement(source: "that is good", target: "that hits"),
        Replacement(source: "that is great", target: "that goes hard"),
        Replacement(source: "that is perfect", target: "that's chef's kiss"),
        Replacement(source: "that is ridiculous", target: "that's wild"),
        Replacement(source: "that is very good", target: "that hits"),
        Replacement(source: "that's amazing", target: "that goes hard"),
        Replacement(source: "that's annoying", target: "that's rough"),
        Replacement(source: "that's good", target: "that hits"),
        Replacement(source: "that's great", target: "that goes hard"),
        Replacement(source: "that's perfect", target: "that's chef's kiss"),
        Replacement(source: "that's ridiculous", target: "that's wild"),
        Replacement(source: "that's very good", target: "that hits"),
        Replacement(source: "that makes sense", target: "that tracks"),
        Replacement(source: "this is a big deal", target: "this is major"),
        Replacement(source: "this is amazing", target: "this goes hard"),
        Replacement(source: "this is bad", target: "this is not it"),
        Replacement(source: "this is good", target: "this hits"),
        Replacement(source: "this is great", target: "this goes hard"),
        Replacement(source: "this is perfect", target: "this is chef's kiss"),
        Replacement(source: "this is ridiculous", target: "this is wild"),
        Replacement(source: "this is very good", target: "this hits"),
        Replacement(source: "too much", target: "a lot"),
        Replacement(source: "we should", target: "we should probably"),
        Replacement(source: "what is going on", target: "what is happening"),
        Replacement(source: "what's going on", target: "what is happening"),
        Replacement(source: "you are right", target: "you're valid"),
        Replacement(source: "you are wrong", target: "that's not it"),
        Replacement(source: "you're right", target: "you're valid"),
        Replacement(source: "you're wrong", target: "that's not it"),
        Replacement(source: "add", target: "drop in"),
        Replacement(source: "annoying", target: "rough"),
        Replacement(source: "amazing", target: "fire"),
        Replacement(source: "app", target: "tool"),
        Replacement(source: "awesome", target: "fire"),
        Replacement(source: "bad", target: "not it"),
        Replacement(source: "best", target: "top"),
        Replacement(source: "better", target: "cleaner"),
        Replacement(source: "boring", target: "mid"),
        Replacement(source: "broken", target: "cooked"),
        Replacement(source: "build", target: "ship"),
        Replacement(source: "busy", target: "booked"),
        Replacement(source: "careful", target: "locked in"),
        Replacement(source: "change", target: "switch up"),
        Replacement(source: "check", target: "check out"),
        Replacement(source: "completely", target: "fully"),
        Replacement(source: "confusing", target: "messy"),
        Replacement(source: "cool", target: "based"),
        Replacement(source: "crazy", target: "wild"),
        Replacement(source: "create", target: "make"),
        Replacement(source: "deadline", target: "due date"),
        Replacement(source: "difficult", target: "rough"),
        Replacement(source: "definitely", target: "for sure"),
        Replacement(source: "different", target: "another"),
        Replacement(source: "done", target: "handled"),
        Replacement(source: "easy", target: "light work"),
        Replacement(source: "excellent", target: "iconic"),
        Replacement(source: "excited", target: "hyped"),
        Replacement(source: "expensive", target: "pricey"),
        Replacement(source: "fast", target: "quick"),
        Replacement(source: "fix", target: "clean up"),
        Replacement(source: "focused", target: "locked in"),
        Replacement(source: "funny", target: "hilarious"),
        Replacement(source: "good", target: "solid"),
        Replacement(source: "great", target: "fire"),
        Replacement(source: "hard", target: "rough"),
        Replacement(source: "hello", target: "hey"),
        Replacement(source: "hi", target: "hey"),
        Replacement(source: "however", target: "but"),
        Replacement(source: "honestly", target: "ngl"),
        Replacement(source: "idea", target: "take"),
        Replacement(source: "important", target: "key"),
        Replacement(source: "improve", target: "level up"),
        Replacement(source: "incredible", target: "insane"),
        Replacement(source: "interface", target: "UI"),
        Replacement(source: "interesting", target: "lowkey interesting"),
        Replacement(source: "model", target: "setup"),
        Replacement(source: "need", target: "gotta have"),
        Replacement(source: "no", target: "nah"),
        Replacement(source: "now", target: "rn"),
        Replacement(source: "output", target: "result"),
        Replacement(source: "perfect", target: "chef's kiss"),
        Replacement(source: "please", target: "pls"),
        Replacement(source: "problem", target: "issue"),
        Replacement(source: "remove", target: "take out"),
        Replacement(source: "quickly", target: "quick"),
        Replacement(source: "really", target: "lowkey"),
        Replacement(source: "ridiculous", target: "wild"),
        Replacement(source: "sad", target: "rough"),
        Replacement(source: "seriously", target: "fr"),
        Replacement(source: "smart", target: "big brain"),
        Replacement(source: "slow", target: "laggy"),
        Replacement(source: "strange", target: "weird"),
        Replacement(source: "surprised", target: "shook"),
        Replacement(source: "test", target: "try"),
        Replacement(source: "thanks", target: "ty"),
        Replacement(source: "tired", target: "fried"),
        Replacement(source: "translation", target: "translation setup"),
        Replacement(source: "try", target: "test"),
        Replacement(source: "unfortunately", target: "sadly"),
        Replacement(source: "want", target: "wanna"),
        Replacement(source: "very", target: "super"),
        Replacement(source: "weird", target: "sus"),
        Replacement(source: "work", target: "do the thing"),
        Replacement(source: "working", target: "running"),
        Replacement(source: "works", target: "hits"),
        Replacement(source: "wrong", target: "off"),
        Replacement(source: "yes", target: "yeah"),
        Replacement(source: "yeah", target: "yeah")
    ]

    private static let genAlphaReplacements = [
        Replacement(source: "absolutely not", target: "big no"),
        Replacement(source: "are you serious", target: "are you for real"),
        Replacement(source: "as soon as possible", target: "asap"),
        Replacement(source: "a big deal", target: "major aura"),
        Replacement(source: "a lot", target: "max"),
        Replacement(source: "all right", target: "bet"),
        Replacement(source: "bad idea", target: "L idea"),
        Replacement(source: "be quiet", target: "stop yapping"),
        Replacement(source: "calm down", target: "chill"),
        Replacement(source: "can you", target: "can u"),
        Replacement(source: "can we", target: "we should"),
        Replacement(source: "check why", target: "figure out why"),
        Replacement(source: "does not work", target: "is cooked"),
        Replacement(source: "doesn't work", target: "is cooked"),
        Replacement(source: "do you understand", target: "does that check out"),
        Replacement(source: "do you want to", target: "are you down to"),
        Replacement(source: "for real", target: "fr"),
        Replacement(source: "good idea", target: "W idea"),
        Replacement(source: "great idea", target: "W idea"),
        Replacement(source: "help me", target: "help me out"),
        Replacement(source: "i agree", target: "W take"),
        Replacement(source: "i am excited", target: "i'm hyped"),
        Replacement(source: "i do not know", target: "idk"),
        Replacement(source: "i don't know", target: "idk"),
        Replacement(source: "i guess", target: "i feel like"),
        Replacement(source: "i like it", target: "it has aura"),
        Replacement(source: "i think", target: "i feel like"),
        Replacement(source: "let me know", target: "lmk"),
        Replacement(source: "look into this", target: "check this out"),
        Replacement(source: "makes sense", target: "checks out"),
        Replacement(source: "no problem", target: "all good"),
        Replacement(source: "not good", target: "cooked"),
        Replacement(source: "not working", target: "cooked"),
        Replacement(source: "okay", target: "bet"),
        Replacement(source: "ok", target: "bet"),
        Replacement(source: "right now", target: "rn"),
        Replacement(source: "sounds good", target: "bet"),
        Replacement(source: "thank you", target: "ty"),
        Replacement(source: "that is amazing", target: "that has aura"),
        Replacement(source: "that is annoying", target: "that's cooked"),
        Replacement(source: "that is bad", target: "that's cooked"),
        Replacement(source: "that is good", target: "that's a W"),
        Replacement(source: "that is great", target: "that's a W"),
        Replacement(source: "that is perfect", target: "max aura"),
        Replacement(source: "that is ridiculous", target: "that's wild"),
        Replacement(source: "that is very good", target: "that's a W"),
        Replacement(source: "that's amazing", target: "that has aura"),
        Replacement(source: "that's annoying", target: "that's cooked"),
        Replacement(source: "that's bad", target: "that's cooked"),
        Replacement(source: "that's good", target: "that's a W"),
        Replacement(source: "that's great", target: "that's a W"),
        Replacement(source: "that's perfect", target: "max aura"),
        Replacement(source: "that's ridiculous", target: "that's wild"),
        Replacement(source: "that's very good", target: "that's a W"),
        Replacement(source: "that makes sense", target: "that checks out"),
        Replacement(source: "this is a big deal", target: "this has major aura"),
        Replacement(source: "this is amazing", target: "this has aura"),
        Replacement(source: "this is bad", target: "this is cooked"),
        Replacement(source: "this is good", target: "this is a W"),
        Replacement(source: "this is great", target: "this is a W"),
        Replacement(source: "this is perfect", target: "this is peak"),
        Replacement(source: "this is ridiculous", target: "this is wild"),
        Replacement(source: "this is very good", target: "this is a W"),
        Replacement(source: "too much", target: "maxed out"),
        Replacement(source: "we should", target: "let's"),
        Replacement(source: "what is going on", target: "what is happening"),
        Replacement(source: "what's going on", target: "what is happening"),
        Replacement(source: "you are right", target: "W take"),
        Replacement(source: "you are wrong", target: "L take"),
        Replacement(source: "you're right", target: "W take"),
        Replacement(source: "you're wrong", target: "L take"),
        Replacement(source: "add", target: "spawn"),
        Replacement(source: "annoying", target: "cooked"),
        Replacement(source: "amazing", target: "goated"),
        Replacement(source: "app", target: "tool"),
        Replacement(source: "awesome", target: "fire"),
        Replacement(source: "bad", target: "L"),
        Replacement(source: "best", target: "goated"),
        Replacement(source: "better", target: "more goated"),
        Replacement(source: "boring", target: "NPC"),
        Replacement(source: "boss", target: "final boss"),
        Replacement(source: "broken", target: "cooked"),
        Replacement(source: "build", target: "craft"),
        Replacement(source: "busy", target: "booked"),
        Replacement(source: "careful", target: "locked in"),
        Replacement(source: "change", target: "remix"),
        Replacement(source: "check", target: "scope"),
        Replacement(source: "client", target: "main character"),
        Replacement(source: "completely", target: "fully"),
        Replacement(source: "confusing", target: "brainrot"),
        Replacement(source: "cool", target: "goated"),
        Replacement(source: "crazy", target: "wild"),
        Replacement(source: "create", target: "spawn"),
        Replacement(source: "customer", target: "main character"),
        Replacement(source: "deadline", target: "due date"),
        Replacement(source: "difficult", target: "cooked"),
        Replacement(source: "definitely", target: "for sure"),
        Replacement(source: "document", target: "doc"),
        Replacement(source: "done", target: "cleared"),
        Replacement(source: "easy", target: "free"),
        Replacement(source: "email", target: "message"),
        Replacement(source: "excellent", target: "goated"),
        Replacement(source: "excited", target: "hyped"),
        Replacement(source: "expensive", target: "taxed"),
        Replacement(source: "fast", target: "speedrun"),
        Replacement(source: "fix", target: "patch"),
        Replacement(source: "focused", target: "locked in"),
        Replacement(source: "funny", target: "goofy"),
        Replacement(source: "good", target: "valid"),
        Replacement(source: "great", target: "goated"),
        Replacement(source: "hard", target: "cooked"),
        Replacement(source: "hello", target: "yo"),
        Replacement(source: "hi", target: "yo"),
        Replacement(source: "however", target: "but"),
        Replacement(source: "honestly", target: "ngl"),
        Replacement(source: "idea", target: "take"),
        Replacement(source: "important", target: "main quest"),
        Replacement(source: "improve", target: "buff"),
        Replacement(source: "incredible", target: "insane"),
        Replacement(source: "interface", target: "UI"),
        Replacement(source: "interesting", target: "kinda fire"),
        Replacement(source: "manager", target: "final boss"),
        Replacement(source: "meeting", target: "sync"),
        Replacement(source: "model", target: "build"),
        Replacement(source: "need", target: "gotta"),
        Replacement(source: "no", target: "nah"),
        Replacement(source: "now", target: "rn"),
        Replacement(source: "office", target: "lobby"),
        Replacement(source: "output", target: "result"),
        Replacement(source: "perfect", target: "peak"),
        Replacement(source: "please", target: "pls"),
        Replacement(source: "problem", target: "issue"),
        Replacement(source: "project", target: "main quest"),
        Replacement(source: "quickly", target: "quick"),
        Replacement(source: "remove", target: "delete"),
        Replacement(source: "really", target: "lowkey"),
        Replacement(source: "ridiculous", target: "wild"),
        Replacement(source: "sad", target: "tragic"),
        Replacement(source: "seriously", target: "fr"),
        Replacement(source: "smart", target: "big brain"),
        Replacement(source: "slow", target: "laggy"),
        Replacement(source: "strange", target: "weird"),
        Replacement(source: "surprised", target: "shook"),
        Replacement(source: "task", target: "quest"),
        Replacement(source: "team", target: "squad"),
        Replacement(source: "test", target: "trial run"),
        Replacement(source: "thanks", target: "ty"),
        Replacement(source: "tired", target: "cooked"),
        Replacement(source: "translation", target: "translation build"),
        Replacement(source: "try", target: "run"),
        Replacement(source: "unfortunately", target: "sadly"),
        Replacement(source: "want", target: "wanna"),
        Replacement(source: "very", target: "super"),
        Replacement(source: "weird", target: "sus"),
        Replacement(source: "work", target: "grind"),
        Replacement(source: "working", target: "online"),
        Replacement(source: "works", target: "goes"),
        Replacement(source: "wrong", target: "L"),
        Replacement(source: "yes", target: "yeah"),
        Replacement(source: "yeah", target: "yeah")
    ]

    private static let boomerReplacements = [
        Replacement(source: "absolutely not", target: "certainly not"),
        Replacement(source: "are you serious", target: "are you kidding"),
        Replacement(source: "as soon as possible", target: "at your earliest convenience"),
        Replacement(source: "a big deal", target: "a major matter"),
        Replacement(source: "a lot", target: "quite a bit"),
        Replacement(source: "all right", target: "alright"),
        Replacement(source: "bad idea", target: "poor idea"),
        Replacement(source: "calm down", target: "take it easy"),
        Replacement(source: "can you", target: "would you mind"),
        Replacement(source: "do you understand", target: "does that make sense"),
        Replacement(source: "do you want to", target: "would you like to"),
        Replacement(source: "for real", target: "really"),
        Replacement(source: "good idea", target: "sensible idea"),
        Replacement(source: "great idea", target: "terrific idea"),
        Replacement(source: "help me", target: "lend me a hand"),
        Replacement(source: "i agree", target: "I agree"),
        Replacement(source: "i am excited", target: "I'm pleased"),
        Replacement(source: "i do not know", target: "I'm not sure"),
        Replacement(source: "i don't know", target: "I'm not sure"),
        Replacement(source: "i guess", target: "I suppose"),
        Replacement(source: "i like it", target: "I like the sound of it"),
        Replacement(source: "i think", target: "I believe"),
        Replacement(source: "let me know", target: "please let me know"),
        Replacement(source: "look into this", target: "take a look at this"),
        Replacement(source: "makes sense", target: "sounds reasonable"),
        Replacement(source: "no problem", target: "not a problem"),
        Replacement(source: "not good", target: "not ideal"),
        Replacement(source: "okay", target: "alright"),
        Replacement(source: "ok", target: "alright"),
        Replacement(source: "sounds good", target: "sounds good to me"),
        Replacement(source: "thank you", target: "thank you kindly"),
        Replacement(source: "that is amazing", target: "that's terrific"),
        Replacement(source: "that is annoying", target: "that's a nuisance"),
        Replacement(source: "that is bad", target: "that's poor"),
        Replacement(source: "that is good", target: "that's fine"),
        Replacement(source: "that is great", target: "that's terrific"),
        Replacement(source: "that is perfect", target: "that's just right"),
        Replacement(source: "that is ridiculous", target: "that's nonsense"),
        Replacement(source: "that is very good", target: "that's quite fine"),
        Replacement(source: "that's amazing", target: "that's terrific"),
        Replacement(source: "that's annoying", target: "that's a nuisance"),
        Replacement(source: "that's bad", target: "that's poor"),
        Replacement(source: "that's good", target: "that's fine"),
        Replacement(source: "that's great", target: "that's terrific"),
        Replacement(source: "that's perfect", target: "that's just right"),
        Replacement(source: "that's ridiculous", target: "that's nonsense"),
        Replacement(source: "that's very good", target: "that's quite fine"),
        Replacement(source: "that makes sense", target: "that sounds reasonable"),
        Replacement(source: "this is a big deal", target: "this is a major matter"),
        Replacement(source: "this is amazing", target: "this is terrific"),
        Replacement(source: "this is bad", target: "this is poor"),
        Replacement(source: "this is good", target: "this is fine"),
        Replacement(source: "this is great", target: "this is terrific"),
        Replacement(source: "this is perfect", target: "this is just right"),
        Replacement(source: "this is ridiculous", target: "this is nonsense"),
        Replacement(source: "this is very good", target: "this is quite fine"),
        Replacement(source: "too much", target: "excessive"),
        Replacement(source: "we should", target: "we ought to"),
        Replacement(source: "what is going on", target: "what is happening"),
        Replacement(source: "what's going on", target: "what is happening"),
        Replacement(source: "you are right", target: "you're correct"),
        Replacement(source: "you are wrong", target: "that's not correct"),
        Replacement(source: "you're right", target: "you're correct"),
        Replacement(source: "you're wrong", target: "that's not correct"),
        Replacement(source: "annoying", target: "a nuisance"),
        Replacement(source: "app", target: "program"),
        Replacement(source: "amazing", target: "terrific"),
        Replacement(source: "awesome", target: "terrific"),
        Replacement(source: "bad", target: "poor"),
        Replacement(source: "boring", target: "dull"),
        Replacement(source: "boss", target: "supervisor"),
        Replacement(source: "busy", target: "swamped"),
        Replacement(source: "careful", target: "cautious"),
        Replacement(source: "cell phone", target: "mobile phone"),
        Replacement(source: "client", target: "customer"),
        Replacement(source: "completely", target: "entirely"),
        Replacement(source: "computer", target: "machine"),
        Replacement(source: "confusing", target: "unclear"),
        Replacement(source: "cool", target: "neat"),
        Replacement(source: "crazy", target: "wild"),
        Replacement(source: "customer", target: "clientele"),
        Replacement(source: "deadline", target: "due date"),
        Replacement(source: "difficult", target: "challenging"),
        Replacement(source: "definitely", target: "certainly"),
        Replacement(source: "document", target: "paperwork"),
        Replacement(source: "easy", target: "straightforward"),
        Replacement(source: "email", target: "electronic mail"),
        Replacement(source: "excellent", target: "outstanding"),
        Replacement(source: "excited", target: "pleased"),
        Replacement(source: "expensive", target: "pricey"),
        Replacement(source: "focused", target: "attentive"),
        Replacement(source: "funny", target: "amusing"),
        Replacement(source: "good", target: "fine"),
        Replacement(source: "great", target: "terrific"),
        Replacement(source: "hard", target: "challenging"),
        Replacement(source: "however", target: "that said"),
        Replacement(source: "honestly", target: "frankly"),
        Replacement(source: "important", target: "critical"),
        Replacement(source: "incredible", target: "remarkable"),
        Replacement(source: "interesting", target: "noteworthy"),
        Replacement(source: "internet", target: "the web"),
        Replacement(source: "manager", target: "supervisor"),
        Replacement(source: "meeting", target: "sit-down"),
        Replacement(source: "message", target: "note"),
        Replacement(source: "no", target: "nope"),
        Replacement(source: "office", target: "workplace"),
        Replacement(source: "perfect", target: "just right"),
        Replacement(source: "phone", target: "telephone"),
        Replacement(source: "please", target: "if you would"),
        Replacement(source: "problem", target: "issue"),
        Replacement(source: "project", target: "assignment"),
        Replacement(source: "quickly", target: "promptly"),
        Replacement(source: "really", target: "quite"),
        Replacement(source: "ridiculous", target: "nonsense"),
        Replacement(source: "sad", target: "unfortunate"),
        Replacement(source: "schedule", target: "calendar"),
        Replacement(source: "seriously", target: "frankly"),
        Replacement(source: "smart", target: "sharp"),
        Replacement(source: "strange", target: "odd"),
        Replacement(source: "surprised", target: "taken aback"),
        Replacement(source: "task", target: "chore"),
        Replacement(source: "team", target: "group"),
        Replacement(source: "thanks", target: "thanks kindly"),
        Replacement(source: "tired", target: "worn out"),
        Replacement(source: "unfortunately", target: "regrettably"),
        Replacement(source: "very", target: "quite"),
        Replacement(source: "weird", target: "odd"),
        Replacement(source: "work", target: "job"),
        Replacement(source: "yes", target: "certainly"),
        Replacement(source: "yeah", target: "yes")
    ]

    private static let alienReplacements = [
        Replacement(source: "answer", target: "decoded response"),
        Replacement(source: "boss", target: "sector commander"),
        Replacement(source: "call", target: "transmission"),
        Replacement(source: "client", target: "earth contact"),
        Replacement(source: "company", target: "colony"),
        Replacement(source: "computer", target: "terminal"),
        Replacement(source: "customer", target: "earth contact"),
        Replacement(source: "deadline", target: "orbital deadline"),
        Replacement(source: "document", target: "data slate"),
        Replacement(source: "email", target: "signal"),
        Replacement(source: "finish", target: "conclude"),
        Replacement(source: "good", target: "stable"),
        Replacement(source: "great", target: "stellar"),
        Replacement(source: "hello", target: "greetings"),
        Replacement(source: "hi", target: "greetings"),
        Replacement(source: "idea", target: "signal"),
        Replacement(source: "issue", target: "anomaly"),
        Replacement(source: "later", target: "next orbit"),
        Replacement(source: "manager", target: "sector commander"),
        Replacement(source: "meeting", target: "council transmission"),
        Replacement(source: "message", target: "transmission"),
        Replacement(source: "no", target: "negative"),
        Replacement(source: "office", target: "command deck"),
        Replacement(source: "people", target: "earthlings"),
        Replacement(source: "person", target: "earthling"),
        Replacement(source: "phone", target: "comms device"),
        Replacement(source: "plan", target: "navigation chart"),
        Replacement(source: "problem", target: "anomaly"),
        Replacement(source: "project", target: "expedition"),
        Replacement(source: "question", target: "query"),
        Replacement(source: "schedule", target: "star chart"),
        Replacement(source: "start", target: "initiate"),
        Replacement(source: "task", target: "objective"),
        Replacement(source: "team", target: "crew of this vessel"),
        Replacement(source: "thanks", target: "gratitude signal"),
        Replacement(source: "today", target: "this solar cycle"),
        Replacement(source: "tomorrow", target: "the next solar cycle"),
        Replacement(source: "update", target: "status ping"),
        Replacement(source: "work", target: "mission"),
        Replacement(source: "yes", target: "affirmative")
    ]

    private static let cowboyReplacements = [
        Replacement(source: "answer", target: "reply"),
        Replacement(source: "bad", target: "rough"),
        Replacement(source: "boss", target: "trail boss"),
        Replacement(source: "call", target: "holler"),
        Replacement(source: "client", target: "customer"),
        Replacement(source: "company", target: "outfit"),
        Replacement(source: "deadline", target: "sundown"),
        Replacement(source: "document", target: "paperwork"),
        Replacement(source: "email", target: "telegram"),
        Replacement(source: "excellent", target: "top-notch"),
        Replacement(source: "finish", target: "wrap up"),
        Replacement(source: "hello", target: "howdy"),
        Replacement(source: "hi", target: "howdy"),
        Replacement(source: "friend", target: "partner"),
        Replacement(source: "hard", target: "tough"),
        Replacement(source: "idea", target: "notion"),
        Replacement(source: "issue", target: "trouble"),
        Replacement(source: "later", target: "down the trail"),
        Replacement(source: "manager", target: "trail boss"),
        Replacement(source: "meeting", target: "roundup"),
        Replacement(source: "message", target: "note"),
        Replacement(source: "no", target: "nope"),
        Replacement(source: "office", target: "ranch"),
        Replacement(source: "plan", target: "trail map"),
        Replacement(source: "good", target: "mighty fine"),
        Replacement(source: "great", target: "mighty fine"),
        Replacement(source: "problem", target: "trouble"),
        Replacement(source: "project", target: "trail ride"),
        Replacement(source: "question", target: "ask"),
        Replacement(source: "schedule", target: "trail map"),
        Replacement(source: "soon", target: "directly"),
        Replacement(source: "start", target: "saddle up"),
        Replacement(source: "task", target: "chore"),
        Replacement(source: "team", target: "posse"),
        Replacement(source: "yes", target: "yep"),
        Replacement(source: "thanks", target: "much obliged"),
        Replacement(source: "update", target: "word")
    ]

    private static let pirateReplacements = [
        Replacement(source: "answer", target: "reply"),
        Replacement(source: "bad", target: "foul"),
        Replacement(source: "boss", target: "captain"),
        Replacement(source: "call", target: "hail"),
        Replacement(source: "client", target: "patron"),
        Replacement(source: "company", target: "fleet"),
        Replacement(source: "customer", target: "patron"),
        Replacement(source: "deadline", target: "tide"),
        Replacement(source: "document", target: "map"),
        Replacement(source: "email", target: "message in a bottle"),
        Replacement(source: "finish", target: "make port"),
        Replacement(source: "good", target: "fine"),
        Replacement(source: "great", target: "grand"),
        Replacement(source: "hello", target: "ahoy"),
        Replacement(source: "hi", target: "ahoy"),
        Replacement(source: "friend", target: "matey"),
        Replacement(source: "idea", target: "treasure map"),
        Replacement(source: "issue", target: "squall"),
        Replacement(source: "later", target: "after the tide"),
        Replacement(source: "meeting", target: "parley"),
        Replacement(source: "message", target: "dispatch"),
        Replacement(source: "money", target: "doubloons"),
        Replacement(source: "plan", target: "course"),
        Replacement(source: "problem", target: "squall"),
        Replacement(source: "project", target: "voyage"),
        Replacement(source: "question", target: "query"),
        Replacement(source: "schedule", target: "sailing orders"),
        Replacement(source: "soon", target: "afore long"),
        Replacement(source: "start", target: "set sail"),
        Replacement(source: "task", target: "errand"),
        Replacement(source: "team", target: "crew"),
        Replacement(source: "update", target: "dispatch"),
        Replacement(source: "yes", target: "aye"),
        Replacement(source: "no", target: "nay"),
        Replacement(source: "thanks", target: "fair winds")
    ]

    private static let robotReplacements = [
        Replacement(source: "answer", target: "response"),
        Replacement(source: "bad", target: "suboptimal"),
        Replacement(source: "boss", target: "primary operator"),
        Replacement(source: "call", target: "voice protocol"),
        Replacement(source: "client", target: "external user"),
        Replacement(source: "company", target: "organization"),
        Replacement(source: "deadline", target: "time constraint"),
        Replacement(source: "document", target: "file"),
        Replacement(source: "easy", target: "low-complexity"),
        Replacement(source: "email", target: "message packet"),
        Replacement(source: "finish", target: "complete"),
        Replacement(source: "good", target: "optimal"),
        Replacement(source: "great", target: "highly optimal"),
        Replacement(source: "hard", target: "high-complexity"),
        Replacement(source: "hello", target: "greetings"),
        Replacement(source: "hi", target: "greetings"),
        Replacement(source: "i think", target: "i calculate"),
        Replacement(source: "issue", target: "fault"),
        Replacement(source: "later", target: "at a later timestamp"),
        Replacement(source: "manager", target: "primary operator"),
        Replacement(source: "maybe", target: "probability uncertain"),
        Replacement(source: "meeting", target: "sync protocol"),
        Replacement(source: "message", target: "data packet"),
        Replacement(source: "yes", target: "affirmative"),
        Replacement(source: "no", target: "negative"),
        Replacement(source: "plan", target: "execution plan"),
        Replacement(source: "problem", target: "error condition"),
        Replacement(source: "project", target: "process"),
        Replacement(source: "question", target: "query"),
        Replacement(source: "schedule", target: "execution schedule"),
        Replacement(source: "soon", target: "imminently"),
        Replacement(source: "start", target: "initialize"),
        Replacement(source: "task", target: "operation"),
        Replacement(source: "team", target: "unit"),
        Replacement(source: "think", target: "process"),
        Replacement(source: "thanks", target: "acknowledgement received"),
        Replacement(source: "update", target: "status report"),
        Replacement(source: "work", target: "process")
    ]

    private static let shakespeareReplacements = [
        Replacement(source: "answer", target: "reply"),
        Replacement(source: "bad", target: "ill"),
        Replacement(source: "before", target: "ere"),
        Replacement(source: "boss", target: "lord"),
        Replacement(source: "call", target: "summons"),
        Replacement(source: "client", target: "patron"),
        Replacement(source: "company", target: "house"),
        Replacement(source: "deadline", target: "appointed hour"),
        Replacement(source: "document", target: "parchment"),
        Replacement(source: "email", target: "missive"),
        Replacement(source: "finish", target: "conclude"),
        Replacement(source: "friend", target: "good companion"),
        Replacement(source: "good", target: "fair"),
        Replacement(source: "great", target: "grand"),
        Replacement(source: "hello", target: "good morrow"),
        Replacement(source: "hi", target: "good morrow"),
        Replacement(source: "idea", target: "notion"),
        Replacement(source: "issue", target: "matter"),
        Replacement(source: "later", target: "anon"),
        Replacement(source: "manager", target: "steward"),
        Replacement(source: "maybe", target: "perchance"),
        Replacement(source: "meeting", target: "council"),
        Replacement(source: "message", target: "missive"),
        Replacement(source: "no", target: "nay"),
        Replacement(source: "plan", target: "design"),
        Replacement(source: "please", target: "prithee"),
        Replacement(source: "problem", target: "vexing matter"),
        Replacement(source: "project", target: "endeavour"),
        Replacement(source: "question", target: "query"),
        Replacement(source: "quickly", target: "with haste"),
        Replacement(source: "very", target: "most"),
        Replacement(source: "really", target: "verily"),
        Replacement(source: "schedule", target: "order of the day"),
        Replacement(source: "soon", target: "presently"),
        Replacement(source: "start", target: "commence"),
        Replacement(source: "task", target: "labour"),
        Replacement(source: "team", target: "fellowship"),
        Replacement(source: "yes", target: "aye"),
        Replacement(source: "thanks", target: "many thanks"),
        Replacement(source: "update", target: "tidings"),
        Replacement(source: "work", target: "labour")
    ]

    static func british(_ text: String) -> String {
        guard containsAlphanumeric(in: text) else {
            return text
        }

        return apply(britishReplacements, to: text)
    }

    static func genZ(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, containsAlphanumeric(in: trimmed) else {
            return text
        }

        return apply(genZReplacements, to: text)
    }

    static func genAlpha(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, containsAlphanumeric(in: trimmed) else {
            return text
        }

        return apply(genAlphaReplacements, to: text)
    }

    static func boomer(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, containsAlphanumeric(in: trimmed) else {
            return text
        }

        return apply(boomerReplacements, to: text)
    }

    static func alien(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, containsAlphanumeric(in: trimmed) else {
            return text
        }

        return apply(alienReplacements, to: text)
    }

    static func cowboy(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, containsAlphanumeric(in: trimmed) else {
            return text
        }

        return apply(cowboyReplacements, to: text)
    }

    static func pirate(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, containsAlphanumeric(in: trimmed) else {
            return text
        }

        return apply(pirateReplacements, to: text)
    }

    static func robot(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, containsAlphanumeric(in: trimmed) else {
            return text
        }

        return apply(robotReplacements, to: text)
    }

    static func shakespeare(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, containsAlphanumeric(in: trimmed) else {
            return text
        }

        return apply(shakespeareReplacements, to: text)
    }

    private static func apply(_ replacements: [Replacement], to text: String) -> String {
        let sortedReplacements = replacements.sorted {
            if $0.source.count == $1.source.count {
                return $0.source < $1.source
            }
            return $0.source.count > $1.source.count
        }
        let replacementBySource = Dictionary(
            uniqueKeysWithValues: sortedReplacements.map { replacement in
                (replacement.source.lowercased(), replacement.target)
            }
        )
        let escapedSources = sortedReplacements
            .map { NSRegularExpression.escapedPattern(for: $0.source) }
            .joined(separator: "|")
        let pattern = #"(?i)(?<![A-Za-z0-9])(?:\#(escapedSources))(?![A-Za-z0-9])"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return text
        }

        var output = text
        let matches = regex.matches(
            in: output,
            range: NSRange(output.startIndex..<output.endIndex, in: output)
        )

        for match in matches.reversed() {
            guard let range = Range(match.range, in: output) else {
                continue
            }
            let matched = String(output[range])
            guard let replacement = replacementBySource[matched.lowercased()] else {
                continue
            }
            output.replaceSubrange(range, with: casedReplacement(replacement, matching: matched))
        }

        return output
    }

    private static func casedReplacement(_ replacement: String, matching matched: String) -> String {
        if matched == matched.uppercased() {
            return replacement.uppercased()
        }

        if let first = matched.first, first.isUppercase {
            return sentenceCase(replacement)
        }

        return replacement
    }

    private static func sentenceCase(_ text: String) -> String {
        guard let first = text.first else {
            return text
        }
        return String(first).uppercased() + String(text.dropFirst())
    }

    private static func containsAlphanumeric(in text: String) -> Bool {
        text.unicodeScalars.contains { CharacterSet.alphanumerics.contains($0) }
    }
}
