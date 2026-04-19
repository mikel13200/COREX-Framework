COREX = COREX or {}
Corex = COREX

Corex.SharedVehicles = Corex.SharedVehicles or {}

Corex.SharedVehicles["bike_rental"] = {
    id = "bike_rental",
    label = "Bike Rental",
    subtitle = "BASIC TRANSPORT",
    currency = "cash",
    purchaseLabel = "Deploy Bike",
    vehicles = {
        {
            model = "bmx",
            label = "BMX",
            category = "street",
            subtitle = "STREET / COMPACT",
            status = "available",
            price = 350,
            description = "Lightweight and quick for short trips through town and tight alleys.",
            image = "https://docs.fivem.net/vehicles/bmx.webp",
            specs = {
                frame = "Steel BMX frame",
                weight = "Light",
                drive = "Single speed",
                brakes = "Rear brake",
                topSpeed = "32 km/h"
            }
        },
        {
            model = "cruiser",
            label = "Cruiser",
            category = "leisure",
            subtitle = "LEISURE / BOARDWALK",
            status = "available",
            price = 300,
            description = "Relaxed geometry for smooth travel around town and safe easy rides.",
            image = "https://docs.fivem.net/vehicles/cruiser.webp",
            specs = {
                frame = "6061 Aluminum",
                weight = "Medium",
                drive = "3-speed internal",
                brakes = "Coaster + V-brake",
                topSpeed = "28 km/h"
            }
        },
        {
            model = "fixter",
            label = "Fixter",
            category = "urban",
            subtitle = "FIXED GEAR / URBAN",
            status = "available",
            price = 500,
            description = "A stripped city bike with quick response and a clean direct-drive feel.",
            image = "https://docs.fivem.net/vehicles/fixter.webp",
            specs = {
                frame = "Chromoly Steel",
                weight = "Light",
                drive = "Fixed / Freewheel",
                brakes = "Front caliper",
                topSpeed = "38 km/h"
            }
        },
        {
            model = "scorcher",
            label = "Scorcher",
            category = "trail",
            subtitle = "TRAIL / ALL-TERRAIN",
            status = "available",
            price = 650,
            description = "Stable on dirt roads and hills when you need longer travel outside the city.",
            image = "https://docs.fivem.net/vehicles/scorcher.webp",
            specs = {
                frame = "Aluminum MTB frame",
                weight = "Medium",
                drive = "Multi-speed",
                brakes = "Disc brake",
                topSpeed = "42 km/h"
            }
        }
    }
}
