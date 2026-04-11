------------------------------------------------------
-- WindowUtils - Icon Browser
-- Browsable, searchable icon picker for CET mods
------------------------------------------------------

local settings = require("core/settings")
local controls = require("modules/controls")
local styles   = require("modules/styles")
local search   = require("modules/search")

local iconbrowser = {}

--------------------------------------------------------------------------------
-- Prefix-to-category mapping (sorted longest-first at load time)
--------------------------------------------------------------------------------

local PREFIX_MAP = {
    -- Account / User
    { prefix = "AccountMultiple",    category = "Account / User" },
    { prefix = "AccountCircle",      category = "Account / User" },
    { prefix = "AccountGroup",       category = "Account / User" },
    { prefix = "Account",            category = "Account / User" },
    { prefix = "Badge",              category = "Account / User" },
    { prefix = "CardAccount",        category = "Account / User" },
    { prefix = "HumanMale",          category = "Account / User" },
    { prefix = "HumanFemale",        category = "Account / User" },
    { prefix = "Human",              category = "Account / User" },

    -- Agriculture
    { prefix = "Barley",             category = "Agriculture" },
    { prefix = "Corn",               category = "Agriculture" },
    { prefix = "Grain",              category = "Agriculture" },
    { prefix = "Greenhouse",         category = "Agriculture" },
    { prefix = "Hops",               category = "Agriculture" },
    { prefix = "Seed",               category = "Agriculture" },
    { prefix = "Silo",               category = "Agriculture" },
    { prefix = "Sprout",             category = "Agriculture" },
    { prefix = "Tractor",            category = "Agriculture" },

    -- Alert / Error
    { prefix = "AlertDecagram",      category = "Alert / Error" },
    { prefix = "AlertCircle",        category = "Alert / Error" },
    { prefix = "AlertOctagon",       category = "Alert / Error" },
    { prefix = "AlertRhombus",       category = "Alert / Error" },
    { prefix = "Alert",              category = "Alert / Error" },

    -- Alpha / Numeric
    { prefix = "Alpha",              category = "Alpha / Numeric" },
    { prefix = "Numeric",            category = "Alpha / Numeric" },
    { prefix = "Roman",              category = "Alpha / Numeric" },

    -- Animal (no short greedy prefixes like "Bat", "Cat", "Dog" that match unrelated icons)
    { prefix = "Bear",               category = "Animal" },
    { prefix = "Bird",               category = "Animal" },
    { prefix = "Butterfly",          category = "Animal" },
    { prefix = "Cow",                category = "Animal" },
    { prefix = "Dolphin",            category = "Animal" },
    { prefix = "Duck",               category = "Animal" },
    { prefix = "Elephant",           category = "Animal" },
    { prefix = "Fish",               category = "Animal" },
    { prefix = "Horseshoe",          category = "Animal" },
    { prefix = "Jellyfish",          category = "Animal" },
    { prefix = "Ladybug",            category = "Animal" },
    { prefix = "Owl",                category = "Animal" },
    { prefix = "Panda",              category = "Animal" },
    { prefix = "Paw",                category = "Animal" },
    { prefix = "Penguin",            category = "Animal" },
    { prefix = "Rabbit",             category = "Animal" },
    { prefix = "Shark",              category = "Animal" },
    { prefix = "Sheep",              category = "Animal" },
    { prefix = "Snail",              category = "Animal" },
    { prefix = "Snake",              category = "Animal" },
    { prefix = "Spider",             category = "Animal" },
    { prefix = "Tortoise",           category = "Animal" },
    { prefix = "Turkey",             category = "Animal" },
    { prefix = "Turtle",             category = "Animal" },
    { prefix = "Unicorn",            category = "Animal" },

    -- Arrange
    { prefix = "ArrangeBring",       category = "Arrange" },
    { prefix = "ArrangeSend",        category = "Arrange" },
    { prefix = "Arrange",            category = "Arrange" },
    { prefix = "FlipHorizontal",     category = "Arrange" },
    { prefix = "FlipVertical",       category = "Arrange" },
    { prefix = "Flip",               category = "Arrange" },
    { prefix = "Rotate",             category = "Arrange" },

    -- Arrow
    { prefix = "ArrowAll",           category = "Arrow" },
    { prefix = "ArrowCollapse",      category = "Arrow" },
    { prefix = "ArrowDecision",      category = "Arrow" },
    { prefix = "ArrowDown",          category = "Arrow" },
    { prefix = "ArrowExpand",        category = "Arrow" },
    { prefix = "ArrowLeft",          category = "Arrow" },
    { prefix = "ArrowRight",         category = "Arrow" },
    { prefix = "ArrowUp",            category = "Arrow" },
    { prefix = "Arrow",              category = "Arrow" },
    { prefix = "ChevronDoubleDown",  category = "Arrow" },
    { prefix = "ChevronDoubleLeft",  category = "Arrow" },
    { prefix = "ChevronDoubleRight", category = "Arrow" },
    { prefix = "ChevronDoubleUp",    category = "Arrow" },
    { prefix = "ChevronDown",        category = "Arrow" },
    { prefix = "ChevronLeft",        category = "Arrow" },
    { prefix = "ChevronRight",       category = "Arrow" },
    { prefix = "ChevronUp",          category = "Arrow" },
    { prefix = "Chevron",            category = "Arrow" },
    { prefix = "Redo",               category = "Arrow" },
    { prefix = "Undo",               category = "Arrow" },

    -- Audio
    { prefix = "Amplifier",          category = "Audio" },
    { prefix = "Earbuds",            category = "Audio" },
    { prefix = "Headphones",         category = "Audio" },
    { prefix = "Microphone",         category = "Audio" },
    { prefix = "Speaker",            category = "Audio" },
    { prefix = "Volume",             category = "Audio" },

    -- Automotive
    { prefix = "CarBattery",         category = "Automotive" },
    { prefix = "CarBrake",           category = "Automotive" },
    { prefix = "CarClock",           category = "Automotive" },
    { prefix = "CarCoolant",         category = "Automotive" },
    { prefix = "CarDoor",            category = "Automotive" },
    { prefix = "CarElectric",        category = "Automotive" },
    { prefix = "CarEstate",          category = "Automotive" },
    { prefix = "CarKey",             category = "Automotive" },
    { prefix = "CarLight",           category = "Automotive" },
    { prefix = "CarSeat",            category = "Automotive" },
    { prefix = "CarSpeed",           category = "Automotive" },
    { prefix = "CarTurbo",           category = "Automotive" },
    { prefix = "CarWash",            category = "Automotive" },
    { prefix = "Car",                category = "Automotive" },
    { prefix = "Engine",             category = "Automotive" },
    { prefix = "GasStation",         category = "Automotive" },
    { prefix = "OilLevel",           category = "Automotive" },
    { prefix = "Steering",           category = "Automotive" },

    -- Banking
    { prefix = "Bank",               category = "Banking" },
    { prefix = "Cash",               category = "Banking" },
    { prefix = "CreditCard",         category = "Banking" },
    { prefix = "Safe",               category = "Banking" },
    { prefix = "Wallet",             category = "Banking" },

    -- Battery
    { prefix = "Battery",            category = "Battery" },

    -- Brand / Logo
    { prefix = "Android",            category = "Brand / Logo" },
    { prefix = "Apple",              category = "Brand / Logo" },
    { prefix = "Bluetooth",          category = "Brand / Logo" },
    { prefix = "Discord",            category = "Brand / Logo" },
    { prefix = "Facebook",           category = "Brand / Logo" },
    { prefix = "Github",             category = "Brand / Logo" },
    { prefix = "Google",             category = "Brand / Logo" },
    { prefix = "Instagram",          category = "Brand / Logo" },
    { prefix = "Linux",              category = "Brand / Logo" },
    { prefix = "Microsoft",          category = "Brand / Logo" },
    { prefix = "Spotify",            category = "Brand / Logo" },
    { prefix = "Steam",              category = "Brand / Logo" },
    { prefix = "Twitter",            category = "Brand / Logo" },
    { prefix = "Ubuntu",             category = "Brand / Logo" },
    { prefix = "Youtube",            category = "Brand / Logo" },

    -- Cellphone / Phone
    { prefix = "Cellphone",          category = "Cellphone / Phone" },
    { prefix = "Phone",              category = "Cellphone / Phone" },

    -- Clothing
    { prefix = "Glasses",            category = "Clothing" },
    { prefix = "HardHat",            category = "Clothing" },
    { prefix = "Hat",                category = "Clothing" },
    { prefix = "Shoe",               category = "Clothing" },
    { prefix = "Sunglasses",         category = "Clothing" },
    { prefix = "Tshirt",             category = "Clothing" },

    -- Cloud
    { prefix = "Cloud",              category = "Cloud" },

    -- Color
    { prefix = "Eyedropper",         category = "Color" },
    { prefix = "Palette",            category = "Color" },
    { prefix = "InvertColors",       category = "Color" },

    -- Currency
    { prefix = "Bitcoin",            category = "Currency" },
    { prefix = "Currency",           category = "Currency" },

    -- Database
    { prefix = "Database",           category = "Database" },

    -- Date / Time
    { prefix = "Calendar",           category = "Date / Time" },
    { prefix = "Clock",              category = "Date / Time" },
    { prefix = "History",            category = "Date / Time" },
    { prefix = "Hourglass",          category = "Date / Time" },
    { prefix = "Timer",              category = "Date / Time" },

    -- Developer / Languages
    { prefix = "ApplicationBraces",  category = "Developer / Languages" },
    { prefix = "CodeBraces",         category = "Developer / Languages" },
    { prefix = "CodeBrackets",       category = "Developer / Languages" },
    { prefix = "CodeJson",           category = "Developer / Languages" },
    { prefix = "CodeTags",           category = "Developer / Languages" },
    { prefix = "Code",               category = "Developer / Languages" },
    { prefix = "Console",            category = "Developer / Languages" },
    { prefix = "Git",                category = "Developer / Languages" },
    { prefix = "Language",           category = "Developer / Languages" },
    { prefix = "Xml",                category = "Developer / Languages" },

    -- Device / Tech
    { prefix = "Desktop",            category = "Device / Tech" },
    { prefix = "Laptop",             category = "Device / Tech" },
    { prefix = "Monitor",            category = "Device / Tech" },
    { prefix = "Router",             category = "Device / Tech" },
    { prefix = "Server",             category = "Device / Tech" },
    { prefix = "Tablet",             category = "Device / Tech" },
    { prefix = "Television",         category = "Device / Tech" },
    { prefix = "Watch",              category = "Device / Tech" },

    -- Drawing / Art
    { prefix = "Brush",              category = "Drawing / Art" },
    { prefix = "Draw",               category = "Drawing / Art" },
    { prefix = "Eraser",             category = "Drawing / Art" },
    { prefix = "Fountain",           category = "Drawing / Art" },
    { prefix = "GestureTap",         category = "Drawing / Art" },
    { prefix = "Grease",             category = "Drawing / Art" },
    { prefix = "Lead",               category = "Drawing / Art" },
    { prefix = "Marker",             category = "Drawing / Art" },
    { prefix = "Pen",                category = "Drawing / Art" },
    { prefix = "Pencil",             category = "Drawing / Art" },
    { prefix = "Spray",              category = "Drawing / Art" },

    -- Edit / Modify
    { prefix = "Check",              category = "Edit / Modify" },
    { prefix = "Checkbox",           category = "Edit / Modify" },
    { prefix = "Close",              category = "Edit / Modify" },
    { prefix = "ContentCopy",        category = "Edit / Modify" },
    { prefix = "ContentCut",         category = "Edit / Modify" },
    { prefix = "ContentPaste",       category = "Edit / Modify" },
    { prefix = "ContentSave",        category = "Edit / Modify" },
    { prefix = "Content",            category = "Edit / Modify" },
    { prefix = "Delete",             category = "Edit / Modify" },
    { prefix = "Drag",               category = "Edit / Modify" },
    { prefix = "Minus",              category = "Edit / Modify" },
    { prefix = "Plus",               category = "Edit / Modify" },
    { prefix = "Select",             category = "Edit / Modify" },
    { prefix = "Trash",              category = "Edit / Modify" },

    -- Emoji
    { prefix = "Emoticon",           category = "Emoji" },
    { prefix = "Sticker",            category = "Emoji" },

    -- Files / Folders
    { prefix = "Attachment",         category = "Files / Folders" },
    { prefix = "Clipboard",          category = "Files / Folders" },
    { prefix = "FileDocument",       category = "Files / Folders" },
    { prefix = "FileMultiple",       category = "Files / Folders" },
    { prefix = "File",               category = "Files / Folders" },
    { prefix = "Folder",             category = "Files / Folders" },
    { prefix = "Paperclip",          category = "Files / Folders" },

    -- Food / Drink
    { prefix = "Beer",               category = "Food / Drink" },
    { prefix = "Bottle",             category = "Food / Drink" },
    { prefix = "Bowl",               category = "Food / Drink" },
    { prefix = "Bread",              category = "Food / Drink" },
    { prefix = "Cake",               category = "Food / Drink" },
    { prefix = "Candy",              category = "Food / Drink" },
    { prefix = "Cheese",             category = "Food / Drink" },
    { prefix = "Coffee",             category = "Food / Drink" },
    { prefix = "Cookie",             category = "Food / Drink" },
    { prefix = "Cupcake",            category = "Food / Drink" },
    { prefix = "Food",               category = "Food / Drink" },
    { prefix = "Fruit",              category = "Food / Drink" },
    { prefix = "GlassCocktail",      category = "Food / Drink" },
    { prefix = "GlassMug",           category = "Food / Drink" },
    { prefix = "GlassWine",          category = "Food / Drink" },
    { prefix = "Hamburger",          category = "Food / Drink" },
    { prefix = "IceCream",           category = "Food / Drink" },
    { prefix = "IcePop",             category = "Food / Drink" },
    { prefix = "Muffin",             category = "Food / Drink" },
    { prefix = "Noodles",            category = "Food / Drink" },
    { prefix = "Pasta",              category = "Food / Drink" },
    { prefix = "Pizza",              category = "Food / Drink" },
    { prefix = "Rice",               category = "Food / Drink" },
    { prefix = "Silverware",         category = "Food / Drink" },
    { prefix = "Teapot",             category = "Food / Drink" },

    -- Form
    { prefix = "FormDropdown",       category = "Form" },
    { prefix = "FormSelect",         category = "Form" },
    { prefix = "FormTextbox",        category = "Form" },
    { prefix = "Form",               category = "Form" },
    { prefix = "RadioboxBlank",      category = "Form" },
    { prefix = "RadioboxMarked",     category = "Form" },
    { prefix = "Toggle",             category = "Form" },

    -- Gaming / RPG
    { prefix = "Controller",         category = "Gaming / RPG" },
    { prefix = "Dice",               category = "Gaming / RPG" },
    { prefix = "Gamepad",            category = "Gaming / RPG" },
    { prefix = "Ghost",              category = "Gaming / RPG" },
    { prefix = "Ninja",              category = "Gaming / RPG" },
    { prefix = "Pac",                category = "Gaming / RPG" },
    { prefix = "Puzzle",             category = "Gaming / RPG" },
    { prefix = "Robot",              category = "Gaming / RPG" },
    { prefix = "Shield",             category = "Gaming / RPG" },
    { prefix = "Sword",              category = "Gaming / RPG" },
    { prefix = "Trophy",             category = "Gaming / RPG" },

    -- Hardware / Tools
    { prefix = "Hammer",             category = "Hardware / Tools" },
    { prefix = "Screwdriver",        category = "Hardware / Tools" },
    { prefix = "Wrench",             category = "Hardware / Tools" },
    { prefix = "Toolbox",            category = "Hardware / Tools" },

    -- Health / Beauty
    { prefix = "Lipstick",           category = "Health / Beauty" },
    { prefix = "Lotion",             category = "Health / Beauty" },

    -- Holiday
    { prefix = "Candle",             category = "Holiday" },
    { prefix = "Firework",           category = "Holiday" },
    { prefix = "Gift",               category = "Holiday" },
    { prefix = "Ornament",           category = "Holiday" },
    { prefix = "PartyPopper",        category = "Holiday" },
    { prefix = "Pine",               category = "Holiday" },
    { prefix = "Pumpkin",            category = "Holiday" },
    { prefix = "Snowflake",          category = "Holiday" },
    { prefix = "Snowman",            category = "Holiday" },

    -- Home Automation
    { prefix = "Blinds",             category = "Home Automation" },
    { prefix = "Ceiling",            category = "Home Automation" },
    { prefix = "Desk",               category = "Home Automation" },
    { prefix = "Door",               category = "Home Automation" },
    { prefix = "Fan",                category = "Home Automation" },
    { prefix = "Garage",             category = "Home Automation" },
    { prefix = "Home",               category = "Home Automation" },
    { prefix = "Lamp",               category = "Home Automation" },
    { prefix = "Lightbulb",          category = "Home Automation" },
    { prefix = "Light",              category = "Home Automation" },
    { prefix = "Radiator",           category = "Home Automation" },
    { prefix = "Thermostat",         category = "Home Automation" },
    { prefix = "Window",             category = "Home Automation" },

    -- Lock
    { prefix = "Key",                category = "Lock" },
    { prefix = "Lock",               category = "Lock" },

    -- Math
    { prefix = "Calculator",         category = "Math" },
    { prefix = "Division",           category = "Math" },
    { prefix = "Exponent",           category = "Math" },
    { prefix = "Infinity",           category = "Math" },
    { prefix = "Math",               category = "Math" },
    { prefix = "Percent",            category = "Math" },
    { prefix = "Sigma",              category = "Math" },

    -- Medical / Hospital
    { prefix = "Ambulance",          category = "Medical / Hospital" },
    { prefix = "Hospital",           category = "Medical / Hospital" },
    { prefix = "Medical",            category = "Medical / Hospital" },
    { prefix = "Needle",             category = "Medical / Hospital" },
    { prefix = "Pill",               category = "Medical / Hospital" },
    { prefix = "Stethoscope",        category = "Medical / Hospital" },

    -- Music
    { prefix = "Music",              category = "Music" },
    { prefix = "Note",               category = "Music" },
    { prefix = "Piano",              category = "Music" },
    { prefix = "Playlist",           category = "Music" },
    { prefix = "Violin",             category = "Music" },

    -- Nature
    { prefix = "Cactus",             category = "Nature" },
    { prefix = "Flower",             category = "Nature" },
    { prefix = "Forest",             category = "Nature" },
    { prefix = "Leaf",               category = "Nature" },
    { prefix = "Mushroom",           category = "Nature" },
    { prefix = "Tree",               category = "Nature" },

    -- Navigation
    { prefix = "Compass",            category = "Navigation" },
    { prefix = "Crosshairs",         category = "Navigation" },
    { prefix = "MapMarker",          category = "Navigation" },
    { prefix = "Map",                category = "Navigation" },
    { prefix = "Navigation",         category = "Navigation" },

    -- Notification
    { prefix = "Bell",               category = "Notification" },
    { prefix = "Bulletin",           category = "Notification" },
    { prefix = "Message",            category = "Notification" },
    { prefix = "Notification",       category = "Notification" },

    -- People / Family
    { prefix = "Baby",               category = "People / Family" },
    { prefix = "Face",               category = "People / Family" },
    { prefix = "Mother",             category = "People / Family" },

    -- Photography
    { prefix = "Camera",             category = "Photography" },
    { prefix = "Image",              category = "Photography" },
    { prefix = "Panorama",           category = "Photography" },

    -- Places
    { prefix = "Beach",              category = "Places" },
    { prefix = "Bridge",             category = "Places" },
    { prefix = "Castle",             category = "Places" },
    { prefix = "Church",             category = "Places" },
    { prefix = "City",               category = "Places" },
    { prefix = "Domain",             category = "Places" },
    { prefix = "Factory",            category = "Places" },
    { prefix = "Island",             category = "Places" },
    { prefix = "Office",             category = "Places" },
    { prefix = "Store",              category = "Places" },
    { prefix = "Warehouse",          category = "Places" },

    -- Printer
    { prefix = "Printer",            category = "Printer" },

    -- Religion
    { prefix = "Cross",              category = "Religion" },
    { prefix = "Mosque",             category = "Religion" },
    { prefix = "Synagogue",          category = "Religion" },

    -- Science
    { prefix = "Atom",               category = "Science" },
    { prefix = "Beaker",             category = "Science" },
    { prefix = "Biohazard",          category = "Science" },
    { prefix = "Flask",              category = "Science" },
    { prefix = "Microscope",         category = "Science" },
    { prefix = "Molecule",           category = "Science" },
    { prefix = "Orbit",              category = "Science" },
    { prefix = "Radioactive",        category = "Science" },
    { prefix = "TestTube",           category = "Science" },

    -- Settings
    { prefix = "Cog",                category = "Settings" },
    { prefix = "Tune",               category = "Settings" },

    -- Shape
    { prefix = "Circle",             category = "Shape" },
    { prefix = "Decagram",           category = "Shape" },
    { prefix = "Diamond",            category = "Shape" },
    { prefix = "Heart",              category = "Shape" },
    { prefix = "Hexagon",            category = "Shape" },
    { prefix = "Octagon",            category = "Shape" },
    { prefix = "Pentagon",           category = "Shape" },
    { prefix = "Rectangle",          category = "Shape" },
    { prefix = "Rhombus",            category = "Shape" },
    { prefix = "Shape",              category = "Shape" },
    { prefix = "Square",             category = "Shape" },
    { prefix = "Star",               category = "Shape" },
    { prefix = "Triangle",           category = "Shape" },

    -- Shopping
    { prefix = "Cart",               category = "Shopping" },
    { prefix = "Shopping",           category = "Shopping" },
    { prefix = "Tag",                category = "Shopping" },

    -- Social Media
    { prefix = "Chat",               category = "Social Media" },
    { prefix = "Comment",            category = "Social Media" },
    { prefix = "Email",              category = "Social Media" },
    { prefix = "Forum",              category = "Social Media" },
    { prefix = "Share",              category = "Social Media" },
    { prefix = "ThumbDown",          category = "Social Media" },
    { prefix = "ThumbUp",            category = "Social Media" },

    -- Sport
    { prefix = "Baseball",           category = "Sport" },
    { prefix = "Basketball",         category = "Sport" },
    { prefix = "Bike",               category = "Sport" },
    { prefix = "Bowling",            category = "Sport" },
    { prefix = "Dumbbell",           category = "Sport" },
    { prefix = "Football",           category = "Sport" },
    { prefix = "Golf",               category = "Sport" },
    { prefix = "Hockey",             category = "Sport" },
    { prefix = "Karate",             category = "Sport" },
    { prefix = "Meditation",         category = "Sport" },
    { prefix = "RunFast",            category = "Sport" },
    { prefix = "Skiing",             category = "Sport" },
    { prefix = "Soccer",             category = "Sport" },
    { prefix = "Swim",               category = "Sport" },
    { prefix = "Tennis",             category = "Sport" },
    { prefix = "Walk",               category = "Sport" },
    { prefix = "Weight",             category = "Sport" },
    { prefix = "Yoga",               category = "Sport" },

    -- Text / Content / Format
    { prefix = "FormatAlign",        category = "Text / Content / Format" },
    { prefix = "FormatBold",         category = "Text / Content / Format" },
    { prefix = "FormatColor",        category = "Text / Content / Format" },
    { prefix = "FormatFloat",        category = "Text / Content / Format" },
    { prefix = "FormatFont",         category = "Text / Content / Format" },
    { prefix = "FormatHeader",       category = "Text / Content / Format" },
    { prefix = "FormatIndent",       category = "Text / Content / Format" },
    { prefix = "FormatItalic",       category = "Text / Content / Format" },
    { prefix = "FormatLetterCase",   category = "Text / Content / Format" },
    { prefix = "FormatLine",         category = "Text / Content / Format" },
    { prefix = "FormatList",         category = "Text / Content / Format" },
    { prefix = "FormatParagraph",    category = "Text / Content / Format" },
    { prefix = "FormatQuote",        category = "Text / Content / Format" },
    { prefix = "FormatSize",         category = "Text / Content / Format" },
    { prefix = "FormatStrikethrough", category = "Text / Content / Format" },
    { prefix = "FormatSubscript",    category = "Text / Content / Format" },
    { prefix = "FormatSuperscript",  category = "Text / Content / Format" },
    { prefix = "FormatText",         category = "Text / Content / Format" },
    { prefix = "FormatTitle",        category = "Text / Content / Format" },
    { prefix = "FormatUnderline",    category = "Text / Content / Format" },
    { prefix = "Format",             category = "Text / Content / Format" },
    { prefix = "Text",               category = "Text / Content / Format" },

    -- Tooltip
    { prefix = "Tooltip",            category = "Tooltip" },
    { prefix = "Information",        category = "Tooltip" },

    -- Transportation
    { prefix = "Airplane",           category = "Transportation" },
    { prefix = "Bicycle",            category = "Transportation" },
    { prefix = "Boat",               category = "Transportation" },
    { prefix = "Bus",                category = "Transportation" },
    { prefix = "Ferry",              category = "Transportation" },
    { prefix = "Helicopter",         category = "Transportation" },
    { prefix = "Moped",              category = "Transportation" },
    { prefix = "Motorbike",          category = "Transportation" },
    { prefix = "Rocket",             category = "Transportation" },
    { prefix = "Sail",               category = "Transportation" },
    { prefix = "Scooter",            category = "Transportation" },
    { prefix = "Subway",             category = "Transportation" },
    { prefix = "Taxi",               category = "Transportation" },
    { prefix = "Train",              category = "Transportation" },
    { prefix = "Tram",               category = "Transportation" },
    { prefix = "Truck",              category = "Transportation" },
    { prefix = "Van",                category = "Transportation" },

    -- Vector
    { prefix = "VectorArrange",      category = "Vector" },
    { prefix = "VectorBezier",       category = "Vector" },
    { prefix = "VectorCircle",       category = "Vector" },
    { prefix = "VectorCombine",      category = "Vector" },
    { prefix = "VectorCurve",        category = "Vector" },
    { prefix = "VectorDifference",   category = "Vector" },
    { prefix = "VectorIntersection", category = "Vector" },
    { prefix = "VectorLine",         category = "Vector" },
    { prefix = "VectorLink",         category = "Vector" },
    { prefix = "VectorPoint",        category = "Vector" },
    { prefix = "VectorPolygon",      category = "Vector" },
    { prefix = "VectorPolyline",     category = "Vector" },
    { prefix = "VectorRadius",       category = "Vector" },
    { prefix = "VectorRectangle",    category = "Vector" },
    { prefix = "VectorSelection",    category = "Vector" },
    { prefix = "VectorSquare",       category = "Vector" },
    { prefix = "VectorTriangle",     category = "Vector" },
    { prefix = "VectorUnion",        category = "Vector" },
    { prefix = "Vector",             category = "Vector" },

    -- Video / Movie
    { prefix = "Camcorder",          category = "Video / Movie" },
    { prefix = "Film",               category = "Video / Movie" },
    { prefix = "Movie",              category = "Video / Movie" },
    { prefix = "Play",               category = "Video / Movie" },
    { prefix = "Video",              category = "Video / Movie" },

    -- View
    { prefix = "Eye",                category = "View" },
    { prefix = "View",               category = "View" },

    -- Weather
    { prefix = "Weather",            category = "Weather" },

    -- GIS (Geographic Information System)
    { prefix = "Earth",              category = "Geographic Information System" },
    { prefix = "Globe",              category = "Geographic Information System" },
    { prefix = "Latitude",           category = "Geographic Information System" },
    { prefix = "Longitude",          category = "Geographic Information System" },
    { prefix = "Web",                category = "Geographic Information System" },

    -- Misc common prefixes that don't fit neatly above
    { prefix = "Download",           category = "Arrow" },
    { prefix = "Upload",             category = "Arrow" },
    { prefix = "Refresh",            category = "Arrow" },
    { prefix = "Sync",               category = "Arrow" },
    { prefix = "Magnify",            category = "Edit / Modify" },
    { prefix = "Search",             category = "Edit / Modify" },
    { prefix = "Sort",               category = "Arrange" },
    { prefix = "Filter",             category = "Arrange" },
    { prefix = "Link",               category = "Edit / Modify" },
    { prefix = "Menu",               category = "View" },
    { prefix = "Dots",               category = "View" },
    { prefix = "Table",              category = "View" },
    { prefix = "Chart",              category = "View" },
    { prefix = "Graph",              category = "View" },
    { prefix = "Signal",             category = "Device / Tech" },
    { prefix = "Wifi",               category = "Device / Tech" },
    { prefix = "Nfc",                category = "Device / Tech" },
    { prefix = "Usb",                category = "Device / Tech" },
    { prefix = "Sd",                 category = "Device / Tech" },
    { prefix = "Sim",                category = "Device / Tech" },
    { prefix = "Power",              category = "Device / Tech" },
    { prefix = "Chip",               category = "Device / Tech" },
    { prefix = "Memory",             category = "Device / Tech" },
    { prefix = "Harddisk",           category = "Device / Tech" },
    { prefix = "Bookmark",           category = "Edit / Modify" },
    { prefix = "Flag",               category = "Edit / Modify" },
}

-- Sort longest-prefix-first
table.sort(PREFIX_MAP, function(a, b) return #a.prefix > #b.prefix end)

-- Pre-compute prefix lengths
for _, entry in ipairs(PREFIX_MAP) do
    entry.len = #entry.prefix
end

--------------------------------------------------------------------------------
-- Category Index
--------------------------------------------------------------------------------

local masterList    = {}
local categoryIndex = {}
local categoryNames = {}
local comboItems    = {}
local indexBuilt    = false

---@param name string PascalCase icon name
---@return string category
local function matchCategory(name)
    for _, entry in ipairs(PREFIX_MAP) do
        if name:sub(1, entry.len) == entry.prefix then
            return entry.category
        end
    end
    return "Other"
end

--- Build the category index from IconGlyphs.
local function buildIndex()
    if indexBuilt then return end
    indexBuilt = true

    if not IconGlyphs then
        settings.debugPrint("IconBrowser: IconGlyphs is nil, deferring index build")
        indexBuilt = false
        return
    end

    local categorySet = {}
    local list = {}
    local count = 0

    for name, glyph in pairs(IconGlyphs) do
        local cat = matchCategory(name)
        count = count + 1
        list[count] = {
            name         = name,
            nameLower    = name:lower(),
            glyph        = glyph,
            category     = cat,
            categoryLower = cat:lower(),
        }
        categoryIndex[name] = cat
        categorySet[cat] = true
    end

    if count == 0 then
        settings.debugPrint("IconBrowser: IconGlyphs is empty, no icons indexed")
    end

    table.sort(list, function(a, b) return a.name < b.name end)
    masterList = list

    local names = {}
    for cat in pairs(categorySet) do
        names[#names + 1] = cat
    end
    table.sort(names)
    categoryNames = names

    -- Cache combo items
    comboItems = { "All" }
    for i = 1, #categoryNames do
        comboItems[i + 1] = categoryNames[i]
    end
end

-- Build at require time; first draw retries if IconGlyphs isn't ready
buildIndex()

--------------------------------------------------------------------------------
-- Category Queries
--------------------------------------------------------------------------------

---@return table categories
function iconbrowser.getCategories()
    if not indexBuilt then buildIndex() end
    return categoryNames
end

---@param name string
---@return string category
function iconbrowser.getCategory(name)
    if not indexBuilt then buildIndex() end
    return categoryIndex[name] or "Other"
end

--------------------------------------------------------------------------------
-- Per-Instance Filter State
--------------------------------------------------------------------------------

local stateRegistry = {}

---@param id string
---@return table state
local function getOrCreateState(id)
    local state = stateRegistry[id]
    if state then return state end

    state = {
        id            = id,
        query         = "",
        category      = nil,
        filtered      = {},
        cacheKey      = nil,
        selected      = nil,
        selectedGlyph = nil,
        changed       = false,
        onSelect      = nil,
        searchState   = nil,
        comboIndex    = 0,
    }
    stateRegistry[id] = state
    return state
end

--- Reset an instance's search, category filter, and selection.
--- Call with no id to reset all instances.
---@param id string|nil
function iconbrowser.reset(id)
    if not id then
        for k in pairs(stateRegistry) do
            iconbrowser.reset(k)
        end
        return
    end
    local state = stateRegistry[id]
    if not state then return end
    state.query = ""
    state.category = nil
    state.comboIndex = 0
    state.cacheKey = nil
    state.selected = nil
    state.selectedGlyph = nil
    state.changed = false
    state._defaultApplied = nil
    if state.searchState then
        state.searchState:clear()
    end
end

--- Rebuild filtered list when query or category changes.
---@param state table
local function rebuildFiltered(state)
    local key = state.query .. "|" .. (state.category or "")
    if key == state.cacheKey then return end

    state.cacheKey = key
    local result = {}
    local count = 0
    local query = state.query
    local cat = state.category

    for i = 1, #masterList do
        local entry = masterList[i]
        if cat and entry.category ~= cat then
            goto continue
        end
        if query ~= "" and not entry.nameLower:find(query, 1, true)
                       and not entry.categoryLower:find(query, 1, true) then
            goto continue
        end
        count = count + 1
        result[count] = entry
        ::continue::
    end

    state.filtered = result
end

--------------------------------------------------------------------------------
-- Grid Renderer
--------------------------------------------------------------------------------

local Scaled = controls.Scaled

--- Render the icon grid with row-skipping for performance.
---@param state table
---@param cellSize number Base cell size (1080p pixels)
local function renderGrid(state, cellSize)
    local filtered = state.filtered
    if #filtered == 0 then
        ImGui.TextDisabled("No icons match")
        return
    end

    cellSize = Scaled(math.max(12, cellSize))
    local spacing = Scaled(4)
    local borderSize = Scaled(2)
    local availWidth, availHeight = ImGui.GetContentRegionAvail()
    local cols = math.max(1, math.floor((availWidth + spacing) / (cellSize + spacing)))

    local totalRows = math.ceil(#filtered / cols)
    local rowHeight = cellSize + spacing
    local scrollY = ImGui.GetScrollY()
    local firstRow = math.floor(scrollY / rowHeight)
    local lastRow = math.min(totalRows - 1, math.ceil((scrollY + availHeight) / rowHeight))

    ImGui.PushStyleVar(ImGuiStyleVar.ItemSpacing, spacing, spacing)

    if firstRow > 0 then
        ImGui.SetCursorPosY(ImGui.GetCursorPosY() + firstRow * rowHeight)
    end

    for row = firstRow, lastRow do
        for col = 0, cols - 1 do
            local idx = row * cols + col + 1
            if idx > #filtered then break end

            local entry = filtered[idx]
            local isSelected = state.selected and entry.name == state.selected

            if col > 0 then
                ImGui.SameLine()
            end

            if isSelected then
                ImGui.PushStyleColor(ImGuiCol.Button, ImGui.GetColorU32(0.2, 0.2, 0.2, 1))
                ImGui.PushStyleColor(ImGuiCol.ButtonHovered, ImGui.GetColorU32(0.3, 0.3, 0.3, 1))
                ImGui.PushStyleColor(ImGuiCol.ButtonActive, ImGui.GetColorU32(0.15, 0.15, 0.15, 1))
                ImGui.PushStyleColor(ImGuiCol.Border, ImGui.GetColorU32(0, 1, 1, 1))
                ImGui.PushStyleVar(ImGuiStyleVar.FrameBorderSize, borderSize)
            else
                ImGui.PushStyleColor(ImGuiCol.Button, ImGui.GetColorU32(0, 0, 0, 0))
                ImGui.PushStyleColor(ImGuiCol.ButtonHovered, ImGui.GetColorU32(0.3, 0.3, 0.3, 0.5))
                ImGui.PushStyleColor(ImGuiCol.ButtonActive, ImGui.GetColorU32(0.2, 0.2, 0.2, 0.5))
                ImGui.PushStyleColor(ImGuiCol.Border, ImGui.GetColorU32(0, 0, 0, 0))
                ImGui.PushStyleVar(ImGuiStyleVar.FrameBorderSize, 0)
            end

            local clicked = ImGui.Button(entry.glyph .. "##icon_" .. entry.name, cellSize, cellSize)

            ImGui.PopStyleVar(1)
            ImGui.PopStyleColor(4)

            if ImGui.IsItemHovered() then
                ImGui.BeginTooltip()
                ImGui.Text(entry.name)
                ImGui.EndTooltip()
            end

            if clicked then
                state.selected = entry.name
                state.selectedGlyph = entry.glyph
                state.changed = true
                if state.onSelect then
                    state.onSelect(entry.name, entry.glyph)
                end
            end
        end
    end

    ImGui.PopStyleVar(1)

    local remainingRows = totalRows - lastRow - 1
    if remainingRows > 0 then
        ImGui.Dummy(0, remainingRows * rowHeight)
    end
end

--------------------------------------------------------------------------------
-- Public Draw API
--------------------------------------------------------------------------------

---@param id string
---@param selected string|nil
---@param onSelect function|nil
---@param opts table|nil
---@return string|nil selected Icon name
---@return string|nil glyph Resolved glyph string
---@return boolean changed True if selection changed this frame
function iconbrowser.draw(id, selected, onSelect, opts)
    if not indexBuilt then buildIndex() end
    if not indexBuilt then return selected, nil, false end

    opts = opts or {}
    local cellSize     = opts.cellSize or 28
    local showSearch   = opts.showSearch ~= false
    local showCategory = opts.showCategory ~= false
    local showPreview  = opts.showPreview or false
    local showCount    = opts.showCount ~= false
    local layout       = opts.layout or "fill"

    local state = getOrCreateState(id)
    state.onSelect = onSelect

    -- Sync caller's selection into state
    if selected ~= nil then
        state.selected = selected
        state.selectedGlyph = IconGlyphs and IconGlyphs[selected] or nil
    end

    -- Apply defaultCategory on first creation only
    if opts.defaultCategory and not state._defaultApplied then
        state._defaultApplied = true
        state.category = opts.defaultCategory
        for i, name in ipairs(categoryNames) do
            if name == opts.defaultCategory then
                state.comboIndex = i
                break
            end
        end
    end

    -- Toolbar
    if showSearch then
        if not state.searchState then
            state.searchState = search.new("iconbrowser_" .. id)
        end
        search.SearchBarPlain(state.searchState, { placeholder = "Search icons...", clearIcon = true })
        if showCategory or showCount then
            ImGui.SameLine()
        end
    end

    if showCategory then
        local comboIdx = state.comboIndex or 0
        ImGui.SetNextItemWidth(Scaled(140))
        styles.PushOutlined()
        local newIdx, changed = ImGui.Combo("##iconcat_" .. id, comboIdx, comboItems, #comboItems)
        styles.PopOutlined()

        if changed then
            state.comboIndex = newIdx
        end

        local idx = state.comboIndex or 0
        state.category = idx > 0 and comboItems[idx + 1] or nil

        if showCount then
            ImGui.SameLine()
        end
    end

    state.query = state.searchState and state.searchState:getQuery():lower() or ""

    rebuildFiltered(state)

    if showCount then
        styles.PushTextMuted()
        ImGui.Text(#state.filtered .. " icons")
        styles.PopTextMuted()
    end

    -- Grid
    if layout == "fixed" then
        controls.Panel("icongrid_" .. id, function()
            renderGrid(state, cellSize)
        end, { resizable = true, height = opts.gridHeight or 300, minHeight = 80 })
    else
        local previewFooter = 0
        if showPreview then
            local spacingY = ImGui.GetStyle().ItemSpacing.y
            previewFooter = (controls.getPanelAutoHeight("iconpreview_" .. id) or 80) + spacingY
        end

        if controls.BeginFillChild("icongrid_" .. id, { footerHeight = previewFooter }) then
            renderGrid(state, cellSize)
        end
        controls.EndFillChild("icongrid_" .. id)
    end

    -- Preview
    if showPreview then
        controls.Panel("iconpreview_" .. id, function()
            if state.selected then
                local glyph = state.selectedGlyph or "?"
                local code = "IconGlyphs." .. state.selected
                local cat = categoryIndex[state.selected] or "Other"

                -- Size icon to span 3 rows
                local frameH = ImGui.GetFrameHeight()
                local spacingY = ImGui.GetStyle().ItemSpacing.y
                local iconH = frameH * 3 + spacingY * 2
                local iconW = iconH

                controls.Button(glyph .. "##preview_" .. id, "label", iconW, iconH)

                if ImGui.IsItemClicked(2) then
                    ImGui.SetClipboardText(code)
                end

                if ImGui.BeginPopupContextItem("##iconpreview_ctx_" .. id) then
                    if ImGui.MenuItem("Copy code to clipboard") then
                        ImGui.SetClipboardText(code)
                    end
                    ImGui.EndPopup()
                end

                ImGui.SameLine()

                ImGui.BeginGroup()
                controls.Button(state.selected .. "##name_" .. id, "label", -1)
                controls.Button(code .. "##code_" .. id, "label", -1)
                controls.Button("Category: " .. cat .. "##cat_" .. id, "label", -1)
                ImGui.EndGroup()
            else
                ImGui.TextDisabled("No icon selected")
            end
        end, { height = "auto" })
    end

    local changed = state.changed or false
    state.changed = false

    return state.selected, state.selectedGlyph, changed
end

return iconbrowser
