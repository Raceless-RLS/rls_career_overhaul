local M = {}

local customers = {{
    id = "CUST001",
    name = "Kenji 'Drift King' Nakamura",
    specialties = {"drift"},
    criteria = {
        performance = {
            drift = {
                min = 0.75
            }
        },
        power = {
            min = 300,
            max = 500
        },
        torque = {
            min = 400,
            max = 500
        },
        numAddedParts = {
            min = 5
        }
    },
    offerRange = {
        min = 0.5,
        max = 1.25
    }
}, {
    id = "CUST002",
    name = "Tina 'Torque Junkie' Rossi",
    specialties = {"drift"},
    criteria = {
        performance = {
            drift = {
                min = 0.6
            }
        },
        powerPerWeight = {
            min = 0.18
        },
        weight = {
            max = 2000
        },
        numAddedParts = {
            min = 4
        }
    },
    offerRange = {
        min = 0.45,
        max = 1.15
    }
}, {
    id = "CUST003",
    name = "Ava 'Apex' Sharma",
    specialties = {"motorsport"},
    criteria = {
        performance = {
            motorsport = {
                min = 0.75
            }
        },
        power = {
            min = 320
        },
        torque = {
            min = 400
        }
    },
    offerRange = {
        min = 0.4,
        max = 1.15
    }
}, {
    id = "CUST004",
    name = "Charlie 'Track Ace' Johnson",
    specialties = {"motorsport"},
    criteria = {
        performance = {
            motorsport = {
                min = 0.85
            }
        },
        power = {
            min = 320,
            max = 500
        },
        torque = {
            min = 400
        },
        numAddedParts = {
            min = 2
        }
    },
    offerRange = {
        min = 0.3,
        max = 1.15
    }
}, {
    id = "CUST005",
    name = "Quinn 'Quarter-Mile' Davis",
    specialties = {"drag"},
    criteria = {
        performance = {
            drag = {
                min = 0.95
            }
        },
        power = {
            min = 320
        },
        powerPerWeight = {
            min = 0.18
        }
    },
    offerRange = {
        min = 0.75,
        max = 1.15
    }
}, {
    id = "CUST006",
    name = "Ricardo 'Speed Seeker' Evans",
    specialties = {"drag"},
    criteria = {
        performance = {
            drag = {
                min = 1
            }
        },
        power = {
            min = 320
        },
        torque = {
            min = 400
        },
        weight = {
            max = 1800
        }
    },
    offerRange = {
        min = 0.5,
        max = 1.2
    }
}, {
    id = "CUST007",
    name = "Olivia 'Trailblazer' Wilson",
    specialties = {"offroad"},
    criteria = {
        performance = {
            offroad = {
                min = 0.7
            }
        },
        torque = {
            min = 400
        }
    },
    offerRange = {
        min = 0.55,
        max = 1.15
    }
}, {
    id = "CUST008",
    name = "Mason 'Mud Hopper' Taylor",
    specialties = {"offroad"},
    criteria = {
        performance = {
            offroad = {
                min = 0.4
            }
        },
        power = {
            min = 300
        },
        torque = {
            min = 380
        },
        numAddedParts = {
            min = 2
        }
    },
    offerRange = {
        min = 0.5,
        max = 1.05
    }
}, {
    id = "CUST009",
    name = "Isabella 'Rally Fanatic' White",
    specialties = {"rally"},
    criteria = {
        performance = {
            rally = {
                min = 0.6
            }
        },
        power = {
            min = 320
        },
        value = {
            max = 70000
        }
    },
    offerRange = {
        min = 0.4,
        max = 1.05
    }
}, {
    id = "CUST010",
    name = "Ethan 'Rally Enthusiast' Martinez",
    specialties = {"rally"},
    criteria = {
        performance = {
            rally = {
                min = 0.8
            }
        },
        torque = {
            min = 400,
            max = 700
        },
        weight = {
            max = 1800
        }
    },
    offerRange = {
        min = 0.5,
        max = 1.2
    }
}, {
    id = "CUST011",
    name = "Sophia 'Rock Crawler' Anderson",
    specialties = {"crawl"},
    criteria = {
        performance = {
            crawl = {
                min = 0.85
            }
        }
    },
    offerRange = {
        min = 0.45,
        max = 1.35
    }
}, {
    id = "CUST012",
    name = "Jackson 'Mountain Goat' Thomas",
    specialties = {"crawl"},
    criteria = {
        performance = {
            crawl = {
                min = 1.0
            }
        },
        powerPerWeight = {
            min = 0.18
        },
        value = {
            max = 75000
        }
    },
    offerRange = {
        min = 0.25,
        max = 1.25
    }
}, {
    id = "CUST013",
    name = "Mia 'Track Day' Garcia",
    specialties = {"apexRacing"},
    criteria = {
        performance = {
            apexRacing = {
                min = 1.0
            }
        },
        power = {
            min = 320
        },
        torque = {
            min = 400
        }
    },
    offerRange = {
        min = 0.5,
        max = 1.25
    }
}, {
    id = "CUST014",
    name = "Aiden 'Circuit' Roberts",
    specialties = {"apexRacing"},
    criteria = {
        performance = {
            apexRacing = {
                min = 1.0
            }
        },
        power = {
            min = 330,
            max = 500
        },
        weight = {
            max = 1700
        }
    },
    offerRange = {
        min = 0.25,
        max = 1.25
    }
}, {
    id = "CUST015",
    name = "Chloe 'Versatile Driver' Rodriguez",
    specialties = {"drift", "motorsport", "rally"},
    criteria = {
        performance = {
            drift = {
                min = 0.65
            },
            motorsport = {
                min = 0.65
            },
            rally = {
                min = 0.65
            }
        },
        power = {
            min = 320
        },
        torque = {
            min = 400
        }
    },
    offerRange = {
        min = 0.4,
        max = 1.25
    }
}, {
    id = "CUST016",
    name = "Liam 'Performance Focused' Lopez",
    specialties = {"drag", "offroad", "motorsport"},
    criteria = {
        performance = {
            drag = {
                min = 0.85
            },
            offroad = {
                min = 0.5
            },
            motorsport = {
                min = 0.6
            }
        },
        powerPerWeight = {
            min = 0.18
        },
        numAddedParts = {
            min = 1,
            max = 8
        }
    },
    offerRange = {
        min = 0.2,
        max = 1.25
    }

}, {
    id = "CUST017",
    name = "Amelia 'Power Seeker' Hill",
    specialties = {},
    criteria = {
        power = {
            min = 600
        },
        torque = {
            min = 700
        },
        numAddedParts = {
            min = 3
        },
        weight = {
            max = 2200
        }
    },
    offerRange = {
        min = 0.3,
        max = 1.25
    }
}, {
    id = "CUST018",
    name = "Noah 'Bargain Hunter' Green",
    specialties = {},
    criteria = {
        value = {
            max = 75000
        },
        weight = {
            max = 2200
        },
        numAddedParts = {
            min = 1,
            max = 12
        }
    },
    offerRange = {
        min = 0.35,
        max = 1.25
    }
}, {
    id = "CUST019",
    name = "Harper 'Low Miles' Baker",
    specialties = {},
    criteria = {
        mileage = {
            max = 50
        },
        value = {
            max = 80000
        }
    },
    offerRange = {
        min = 0.15,
        max = 1.05
    }
}, {
    id = "CUST020",
    name = "Evelyn 'All Terrain' King",
    specialties = {"drift", "motorsport", "drag", "rally"},
    criteria = {
        performance = {
            drift = {
                min = 0.5
            },
            motorsport = {
                min = 0.75
            },
            drag = {
                min = 0.85
            },
            rally = {
                min = 0.75
            }
        },
        power = {
            min = 320,
            max = 500
        },
        torque = {
            min = 400,
            max = 500
        },
        powerPerWeight = {
            min = 0.18
        },
        value = {
            max = 100000
        }
    },
    offerRange = {
        min = 0.25,
        max = 1.3
    }
}, -- Unlimited Customers (criteria defined only as minimums)
{
    id = "CUST021",
    name = "William 'Drift Expert' Wright",
    specialties = {"drift"},
    criteria = {
        performance = {
            drift = {
                min = 0.85
            } -- no max specified
        },
        power = {
            min = 600
        },
        torque = {
            min = 700
        }
    },
    offerRange = {
        min = 0.4,
        max = 1.25
    }

}, {
    id = "CUST022",
    name = "Ella 'Motorsport Master' Lopez",
    specialties = {"motorsport"},
    criteria = {
        performance = {
            motorsport = {
                min = 0.95
            } -- no max specified
        },
        power = {
            min = 600
        },
        torque = {
            min = 700
        }
    },
    offerRange = {
        min = 0.35,
        max = 1.25
    }
}, {
    id = "CUST023",
    name = "James 'Drag Strip' Phillips",
    specialties = {"drag"},
    criteria = {
        performance = {
            drag = {
                min = 1.1
            } -- no max specified
        },
        power = {
            min = 800
        },
        powerPerWeight = {
            min = 0.4
        }
    },
    offerRange = {
        min = 0.5,
        max = 1.3
    }
}, {
    id = "CUST024",
    name = "Lily 'Offroad Pro' Mitchell",
    specialties = {"offroad"},
    criteria = {
        performance = {
            offroad = {
                min = 1.0
            } -- no max specified
        },
        torque = {
            min = 400
        }
    },
    offerRange = {
        min = 0.25,
        max = 1.3
    }

}, {
    id = "CUST025",
    name = "Benjamin 'Rally Champ' Gray",
    specialties = {"rally"},
    criteria = {
        performance = {
            rally = {
                min = 1.1
            } -- no max specified
        },
        power = {
            min = 500
        }
    },
    offerRange = {
        min = 0.15,
        max = 1.3
    }

}, {
    id = "CUST026",
    name = "Victoria 'Versatile' Hayes",
    specialties = {"drift", "motorsport", "drag", "offroad", "rally", "crawl", "apexRacing"},
    criteria = {
        performance = {
            drift = {
                min = 0.65
            },
            motorsport = {
                min = 0.65
            },
            drag = {
                min = 1.1
            },
            offroad = {
                min = 1
            },
            rally = {
                min = 1
            },
            crawl = {
                min = 0.85
            },
            apexRacing = {
                min = 1.05
            }
        },
        power = {
            min = 600
        },
        torque = {
            min = 750
        }
    },
    offerRange = {
        min = 0.85,
        max = 1.55
    }
}, -- Additional Unlimited Customers That Do NOT Look at Performance
{
    id = "CUST027",
    name = "Gabriel 'Power Hungry' Price",
    specialties = {},
    criteria = {
        power = {
            min = 800
        },
        torque = {
            min = 1000
        }
        -- No performance criteria
    },
    offerRange = {
        min = 0.35,
        max = 1.15
    }
}, {
    id = "CUST028",
    name = "Abigail 'Budget-Conscious' Bennett",
    specialties = {},
    criteria = {
        value = {
            max = 65000
        },
        weight = {
            max = 2500
        }
        -- No performance criteria
    },
    offerRange = {
        min = 0.1,
        max = 0.95
    }
}, {
    id = "CUST029",
    name = "Alexander 'Value Seeker' Wood",
    specialties = {},
    criteria = {
        power = {
            min = 300
        },
        torque = {
            min = 350
        },
        value = {
            max = 80000
        }
        -- No performance criteria
    },
    offerRange = {
        min = 0.15,
        max = 0.95
    }
}, {
    id = "CUST030",
    name = "Naomi 'Fresh Wheels' Walker",
    specialties = {},
    criteria = {
        mileage = {
            max = 80
        },
        powerPerWeight = {
            min = 0.15
        }
        -- No performance criteria
    },
    offerRange = {
        min = 0.25,
        max = 1.05
    }
}, {
    id = "CUST031",
    name = "Belasco Auto",
    specialties = {}, -- general car dealership
    criteria = {
        mileage = {
            max = 45000
        }, -- quality used vehicles (low miles)
        value = {
            max = 65000
        }, -- affordable, quality vehicles
        power = {
            min = 320
        },
        torque = {
            min = 400
        }
    },
    offerRange = {
        min = 0.3,
        max = 1.05
    } -- no range provided → default
}, -- Jefferson Motors (sells Custom American cars)
{
    id = "CUST032",
    name = "Jefferson Motors",
    specialties = {"motorsport"},
    criteria = {
        power = {
            min = 320
        },
        torque = {
            min = 400
        },
        mileage = {
            max = 1200
        },
        value = {
            max = 165000
        }
    },
    offerRange = {
        min = 0.05,
        max = 1.05
    }
}, -- Rich's Motor Company (sells prestige, high–quality vehicles)
{
    id = "CUST033",
    name = "Rich's Motor Company",
    specialties = {"apexRacing"},
    criteria = {
        value = {
            min = 120000
        }, -- they require higher–priced, prestigious vehicles
        mileage = {
            max = 1000
        },
        power = {
            min = 350
        },
        torque = {
            min = 420
        }
    },
    offerRange = {
        min = 0.15,
        max = 1.05
    }
}, -- Quarryside Auto Sales (sells used trucks and vans)
{
    id = "CUST034",
    name = "Quarryside Auto Sales",
    specialties = {"crawl"},
    criteria = {
        performance = {
            crawl = {
                min = 0.5
            }
        },
        power = {
            min = 350
        },
        torque = {
            min = 450
        },
        mileage = {
            max = 160000
        },
        value = {
            max = 65000
        }
    },
    offerRange = {
        min = 0.75,
        max = 1.25
    }
}, -- Smash Rollers (FrameDealership – starting builds)
{
    id = "CUST035",
    name = "Smash Rollers",
    specialties = {}, -- a base for builds; not focused on performance
    criteria = {
        value = {
            max = 50000
        },
        mileage = {
            min = 200000
        },
        power = {
            max = 400
        },
        torque = {
            max = 500
        },
        numRemovedParts = {
            min = 7
        },
        accidents = {
            min = 2
        }
    },
    offerRange = {
        min = 0.2,
        max = 0.75
    }
}, -- Rocking Rally (sells rally vehicles)
{
    id = "CUST036",
    name = "Rocking Rally",
    specialties = {"rally"},
    criteria = {
        performance = {
            rally = {
                min = 0.6
            }
        },
        power = {
            min = 320
        },
        torque = {
            min = 400
        }
    },
    offerRange = {
        min = 0.7,
        max = 1.3
    }
}, -- Clockwise Drag Racing (sells drag vehicles)
{
    id = "CUST037",
    name = "Clockwise Drag Racing",
    specialties = {"drag"},
    criteria = {
        performance = {
            drag = {
                min = 1.2
            }
        },
        power = {
            min = 600
        },
        torque = {
            min = 800
        },
        mileage = {
            max = 200000
        }

    },
    offerRange = {
        min = 0.25,
        max = 1.35
    }
}, -- DriftGear Dealer (sells drift vehicles)
{
    id = "CUST038",
    name = "DriftGear Dealer",
    specialties = {"drift"},
    criteria = {
        performance = {
            drift = {
                min = 0.75
            }
        },
        power = {
            min = 300
        },
        torque = {
            min = 400
        },
        mileage = {
            max = 200000
        }
    },
    offerRange = {
        min = 0.25,
        max = 1.25
    }
}, -- Gizamn's Rod Shop (sells modified/drift vehicles)
{
    id = "CUST039",
    name = "Gizamn's Rod Shop",
    specialties = {"drag"},
    criteria = {
        performance = {
            drag = {
                min = 1
            }
        },
        power = {
            min = 600
        },
        torque = {
            min = 800
        },
        mileage = {
            max = 100000
        }
    },
    offerRange = {
        min = 0.25,
        max = 1.25
    }
}, -- TJs Offroad World (sells offroad vehicles)
{
    id = "CUST040",
    name = "TJs Offroad World",
    specialties = {"offroad"},
    criteria = {
        performance = {
            offroad = {
                min = 0.75
            }
        },
        power = {
            min = 320
        },
        torque = {
            min = 400
        },
        mileage = {
            max = 150000
        }
    },
    offerRange = {
        min = 0.3,
        max = 1.3
    }
}, -- Trusted Auto Sales (sells discounted cars)
{
    id = "CUST041",
    name = "Trusted Auto Sales",
    specialties = {},
    criteria = {
        value = {
            max = 65000
        },
        mileage = {
            max = 1000000
        },
        power = {
            min = 100
        },
        torque = {
            min = 100
        }
    },
    offerRange = {
        min = 0.15,
        max = 0.8
    }
}, {
    id = "CUST042",
    name = "Joe's Junk",
    specialties = {}, -- no performance focus
    criteria = {
        value = {
            max = 45000
        },
        mileage = {
            max = 450000
        },
        power = {
            min = 100
        },
        torque = {
            min = 100
        }
    },
    offerRange = {
        min = 0.1,
        max = 0.75
    }
}, -- Fast Automotive (sells fast race cars)
{
    id = "CUST043",
    name = "Fast Automotive",
    specialties = {"motorsport"},
    criteria = {
        performance = {
            motorsport = {
                min = 0.6
            }
        },
        power = {
            min = 320
        },
        torque = {
            min = 400
        },
        mileage = {
            max = 30000
        }
    },
    offerRange = {
        min = 0.15,
        max = 1.3
    }
}, {
    id = "CUST044",
    name = "West Coast Customs",
    specialties = {},

    criteria = {
        mileage = {
            max = 80
        },
        powerPerWeight = {
            min = 0.15
        },
        numAddedParts = {
            min = 7
        }
        -- No performance criteria
    },
    offerRange = {
        min = 0.55,
        max = 1.3
    }
}, {
    id = "CUST045",
    name = "Phil 'Builds' Evans",
    specialties = {},
    criteria = {
        powerPerWeight = {
            min = 0.15
        },
        numAddedParts = {
            min = 7
        }
        -- No performance criteria
    },
    offerRange = {
        min = 0.65,
        max = 1.25
    }
}, {
    id = "CUST046",
    name = "Meetup Maven Mia",
    specialties = {}, -- No specific performance focus
    criteria = {
        rep = {
            min = 3.5
        },
        numAddedParts = {
            min = 5
        },
        value = {
            max = 100000
        }
    },
    offerRange = {
        min = 0.8,
        max = 1.25
    } -- Higher offer range
}, {
    id = "CUST047",
    name = "Showoff King Kai",
    specialties = {}, -- No specific performance focus
    criteria = {
        rep = {
            min = 5
        }, -- Very high rep requirement
        power = {
            min = 450
        },
        torque = {
            min = 500
        },
        value = {
            min = 150000
        },
        numAddedParts = {
            min = 2
        }
    },
    offerRange = {
        min = 0.9,
        max = 1.35
    } -- Even higher offer range
}, {
    id = "CUST048",
    name = "Shady Shane",
    specialties = {}, -- No specific performance focus
    criteria = {
        rep = {
            min = 0.3
        }, -- Very high rep requirement
        power = {
            min = 250
        },
        torque = {
            min = 300
        }
    },
    offerRange = {
        min = 0.15,
        max = 1.25
    }
}, {
    id = "CUST049",
    name = "Cruise Collective",
    specialties = {}, -- No specific performance focus
    criteria = {
        rep = {
            min = 10
        }, -- Very high rep requirement
        powerPerWeight = {
            max = 0.25
        },
        numAddedParts = {
            min = 2
        }
    },
    offerRange = {
        min = 0.85,
        max = 1.45
    }
}, {
    id = "CUST050",
    name = "Elden's Classics",
    specialties = {}, -- No specific performance focus
    criteria = {
        performance = {
            drag = {
                max = 0
            }
        },
        numAddedParts = {
            max = 1
        },
        year = {
            max = 2000
        },
        mileage = {
            max = 100
        },
        value = {
            max = 100000
        }
    },
    offerRange = {
        min = 0.1,
        max = 1.25
    }
}, {
    id = "CUST051",
    name = "Jack 'Stanced' Jackson",
    specialties = {}, -- No specific performance focus
    criteria = {
        performance = {
            motorsport = {
                min = 0.75
            },
            drift = {
                min = 0.65
            },
            apexRacing = {
                min = 0.75
            }
        },
        rep = {
            min = 5
        },
        numAddedParts = {
            min = 2
        },
        power = {
            min = 400
        },
        torque = {
            min = 500
        }
    },
    offerRange = {
        min = 0.45,
        max = 1.5
    }
}, {
    id = "CUST052",
    name = "Tuned Tony Thompson",
    specialties = {},
    criteria = {
        performance = {
            motorsport = {
                min = 0.75
            }
        },
        mileage = {
            min = 100000
        },
        powerPerWeight = {
            min = 0.15
        },
        numAddedParts = {
            min = 12
        },
        rep = {
            min = 3
        }
    },
    offerRange = {
        min = 0.65,
        max = 1.35
    }
}, {
    id = "CUST053",
    name = "Getaway Girl Gina",
    specialties = {},
    criteria = {
        performance = {
            motorsport = {
                min = 0.75
            }
        },
        evades = {
            min = 3
        },
        rep = {
            min = 3
        },
        arrests = {
            max = 0
        }
    },
    offerRange = {
        min = 0.65,
        max = 1.35
    }
}, {
    id = "CUST054",
    name = "Speed Demon Sam",
    specialties = {},
    criteria = {
        performance = {
            motorsport = {
                min = 1
            }
        },
        powerPerWeight = {
            min = 0.25
        }
    },
    offerRange = {
        min = 0.85,
        max = 1.35
    }
}, {
    id = "CUST055",
    name = "Stock Car Steve",
    specialties = {},
    criteria = {
        performance = {
            motorsport = {
                min = 1
            }
        },
        powerPerWeight = {
            min = 0.25
        },
        numRemovedParts = {
            max = 0
        }
    },
    offerRange = {
        min = 0.85,
        max = 1.35
    }
}, {
    id = "CUST056",
    name = "Ryker 'Drift Rookie' Thompson",
    specialties = {"drift"},
    criteria = {
        performance = {
            drift = {
                min = 0.5
            }
        },
        power = {
            min = 280
        },
        torque = {
            min = 350
        },
        numAddedParts = {
            min = 1
        }
    },
    offerRange = {
        min = 0.2,
        max = 1.0
    }
}, {
    id = "CUST057",
    name = "Kazu 'Sideways Starter' Mori",
    specialties = {"drift"},
    criteria = {
        performance = {
            drift = {
                min = 0.55
            }
        },
        power = {
            min = 300
        },
        torque = {
            min = 360
        }
    },
    offerRange = {
        min = 0.25,
        max = 1.05
    }
}, {
    id = "CUST058",
    name = "Nina 'Drift Diva' Martinez",
    specialties = {"drift"},
    criteria = {
        performance = {
            drift = {
                min = 0.6
            }
        },
        power = {
            min = 310
        },
        torque = {
            min = 370
        },
        numAddedParts = {
            min = 2
        }
    },
    offerRange = {
        min = 0.3,
        max = 1.05
    }
}, {
    id = "CUST059",
    name = "Owen 'Slide Master' Brown",
    specialties = {"drift"},
    criteria = {
        performance = {
            drift = {
                min = 0.65
            }
        },
        power = {
            min = 320
        },
        torque = {
            min = 380
        }
    },
    offerRange = {
        min = 0.35,
        max = 1.1
    }
}, {
    id = "CUST060",
    name = "Lola 'Neon Drift' Garcia",
    specialties = {"drift"},
    criteria = {
        performance = {
            drift = {
                min = 0.7
            }
        },
        power = {
            min = 330
        },
        torque = {
            min = 390
        },
        numAddedParts = {
            min = 3
        }
    },
    offerRange = {
        min = 0.4,
        max = 1.15
    }
}, {
    id = "CUST061",
    name = "Finn 'Fury Drift' O'Connor",
    specialties = {"drift"},
    criteria = {
        performance = {
            drift = {
                min = 0.75
            }
        },
        power = {
            min = 340
        },
        torque = {
            min = 400
        }
    },
    offerRange = {
        min = 0.45,
        max = 1.2
    }
}, {
    id = "CUST062",
    name = "Elena 'Slick Slide' Petrova",
    specialties = {"drift"},
    criteria = {
        performance = {
            drift = {
                min = 0.8
            }
        },
        power = {
            min = 350
        },
        torque = {
            min = 410
        },
        numAddedParts = {
            min = 4
        }
    },
    offerRange = {
        min = 0.5,
        max = 1.25
    }
}, {
    id = "CUST063",
    name = "Marco 'Curve King' Rossi",
    specialties = {"drift"},
    criteria = {
        performance = {
            drift = {
                min = 0.85
            }
        },
        power = {
            min = 360
        },
        torque = {
            min = 420
        }
    },
    offerRange = {
        min = 0.55,
        max = 1.3
    }
}, {
    id = "CUST064",
    name = "Sasha 'Apex Drift' Ivanov",
    specialties = {"drift"},
    criteria = {
        performance = {
            drift = {
                min = 0.9
            }
        },
        power = {
            min = 370
        },
        torque = {
            min = 430
        },
        numAddedParts = {
            min = 5
        }
    },
    offerRange = {
        min = 0.6,
        max = 1.35
    }
}, {
    id = "CUST065",
    name = "Jin 'Precision Slide' Kim",
    specialties = {"drift"},
    criteria = {
        performance = {
            drift = {
                min = 0.95
            }
        },
        power = {
            min = 380
        },
        torque = {
            min = 440
        }
    },
    offerRange = {
        min = 0.65,
        max = 1.4
    }
}, -- Motorsport Enthusiasts (10)
{
    id = "CUST066",
    name = "Victor 'Circuit Racer' Lopez",
    specialties = {"motorsport"},
    criteria = {
        performance = {
            motorsport = {
                min = 0.55
            }
        },
        power = {
            min = 300
        },
        torque = {
            min = 350
        }
    },
    offerRange = {
        min = 0.25,
        max = 0.95
    }
}, {
    id = "CUST067",
    name = "Sierra 'Speed Circuit' Martinez",
    specialties = {"motorsport"},
    criteria = {
        performance = {
            motorsport = {
                min = 0.6
            }
        },
        power = {
            min = 310
        },
        torque = {
            min = 360
        }
    },
    offerRange = {
        min = 0.3,
        max = 1.0
    }
}, {
    id = "CUST068",
    name = "Derek 'Track Tactician' Nguyen",
    specialties = {"motorsport"},
    criteria = {
        performance = {
            motorsport = {
                min = 0.65
            }
        },
        power = {
            min = 320
        },
        torque = {
            min = 370
        },
        numAddedParts = {
            min = 2
        }
    },
    offerRange = {
        min = 0.35,
        max = 1.05
    }
}, {
    id = "CUST069",
    name = "Maya 'Lap Leader' Patel",
    specialties = {"motorsport"},
    criteria = {
        performance = {
            motorsport = {
                min = 0.7
            }
        },
        power = {
            min = 330
        },
        torque = {
            min = 380
        }
    },
    offerRange = {
        min = 0.4,
        max = 1.1
    }
}, {
    id = "CUST070",
    name = "Ethan 'Fast Lane' Murphy",
    specialties = {"motorsport"},
    criteria = {
        performance = {
            motorsport = {
                min = 0.8
            }
        },
        power = {
            min = 340
        },
        torque = {
            min = 390
        }
    },
    offerRange = {
        min = 0.45,
        max = 1.15
    }
}, {
    id = "CUST071",
    name = "Zara 'Race Queen' Khan",
    specialties = {"motorsport"},
    criteria = {
        performance = {
            motorsport = {
                min = 0.9
            }
        },
        power = {
            min = 350
        },
        torque = {
            min = 400
        },
        numAddedParts = {
            min = 3
        }
    },
    offerRange = {
        min = 0.5,
        max = 1.2
    }
}, {
    id = "CUST072",
    name = "Leo 'Speedster' Garcia",
    specialties = {"motorsport"},
    criteria = {
        performance = {
            motorsport = {
                min = 0.95
            }
        },
        power = {
            min = 360
        },
        torque = {
            min = 410
        }
    },
    offerRange = {
        min = 0.55,
        max = 1.25
    }
}, {
    id = "CUST073",
    name = "Ivy 'Track Titan' Rodriguez",
    specialties = {"motorsport"},
    criteria = {
        performance = {
            motorsport = {
                min = 1.1
            }
        },
        power = {
            min = 370
        },
        torque = {
            min = 420
        },
        numAddedParts = {
            min = 4
        }
    },
    offerRange = {
        min = 0.6,
        max = 1.25
    }
}, {
    id = "CUST074",
    name = "Oscar 'Pit Crew' Hernandez",
    specialties = {"motorsport"},
    criteria = {
        performance = {
            motorsport = {
                min = 1.25
            }
        },
        power = {
            min = 380
        },
        torque = {
            min = 430
        }
    },
    offerRange = {
        min = 0.65,
        max = 1.3
    }
}, {
    id = "CUST075",
    name = "Nora 'Victory Lane' Smith",
    specialties = {"motorsport"},
    criteria = {
        performance = {
            motorsport = {
                min = 1.3
            }
        },
        power = {
            min = 390
        },
        torque = {
            min = 440
        },
        numAddedParts = {
            min = 5
        }
    },
    offerRange = {
        min = 0.7,
        max = 1.4
    }
}, -- Drag Racers (10)
{
    id = "CUST076",
    name = "Blaze 'Nitro' Carter",
    specialties = {"drag"},
    criteria = {
        performance = {
            drag = {
                min = 0.7
            }
        },
        power = {
            min = 320
        },
        torque = {
            min = 380
        }
    },
    offerRange = {
        min = 0.3,
        max = 1.0
    }
}, {
    id = "CUST077",
    name = "Rex 'Burnout' Allen",
    specialties = {"drag"},
    criteria = {
        performance = {
            drag = {
                min = 0.75
            }
        },
        power = {
            min = 330
        },
        torque = {
            min = 390
        }
    },
    offerRange = {
        min = 0.35,
        max = 1.05
    }
}, {
    id = "CUST078",
    name = "Jade 'Quarter-Mile' Brooks",
    specialties = {"drag"},
    criteria = {
        performance = {
            drag = {
                min = 1
            }
        },
        power = {
            min = 340
        },
        torque = {
            min = 400
        },
        numAddedParts = {
            min = 2
        }
    },
    offerRange = {
        min = 0.4,
        max = 1.1
    }
}, {
    id = "CUST079",
    name = "Ty 'Dragster' Evans",
    specialties = {"drag"},
    criteria = {
        performance = {
            drag = {
                min = 1.15
            }
        },
        power = {
            min = 350
        },
        torque = {
            min = 410
        }
    },
    offerRange = {
        min = 0.45,
        max = 1.15
    }
}, {
    id = "CUST080",
    name = "Piper 'Launch Pad' Ford",
    specialties = {"drag"},
    criteria = {
        performance = {
            drag = {
                min = 1.3
            }
        },
        power = {
            min = 360
        },
        torque = {
            min = 420
        }
    },
    offerRange = {
        min = 0.5,
        max = 1.2
    }
}, {
    id = "CUST081",
    name = "Cade 'Rocket' Martin",
    specialties = {"drag"},
    criteria = {
        performance = {
            drag = {
                min = 1.45
            }
        },
        power = {
            min = 370
        },
        torque = {
            min = 430
        },
        numAddedParts = {
            min = 3
        }
    },
    offerRange = {
        min = 0.55,
        max = 1.25
    }
}, {
    id = "CUST082",
    name = "Zane 'Speed Bomb' Reed",
    specialties = {"drag"},
    criteria = {
        performance = {
            drag = {
                min = 1.55
            }
        },
        power = {
            min = 380
        },
        torque = {
            min = 440
        }
    },
    offerRange = {
        min = 0.6,
        max = 1.3
    }
}, {
    id = "CUST083",
    name = "Lana 'Shift King' Parker",
    specialties = {"drag"},
    criteria = {
        performance = {
            drag = {
                min = 1.6
            }
        },
        power = {
            min = 390
        },
        torque = {
            min = 450
        }
    },
    offerRange = {
        min = 0.65,
        max = 1.35
    }
}, {
    id = "CUST084",
    name = "Gage 'Drag Dominator' Foster",
    specialties = {"drag"},
    criteria = {
        performance = {
            drag = {
                min = 1.65
            }
        },
        power = {
            min = 400
        },
        torque = {
            min = 460
        },
        numAddedParts = {
            min = 2
        }
    },
    offerRange = {
        min = 0.7,
        max = 1.4
    }
}, {
    id = "CUST085",
    name = "Nova 'Burnout Queen' Sanchez",
    specialties = {"drag"},
    criteria = {
        performance = {
            drag = {
                min = 1.7
            }
        },
        power = {
            min = 410
        },
        torque = {
            min = 470
        }
    },
    offerRange = {
        min = 0.75,
        max = 1.45
    }
}, -- Offroad Adventurers (10)
{
    id = "CUST086",
    name = "Tucker 'Trail Blazer' Roberts",
    specialties = {"offroad"},
    criteria = {
        performance = {
            offroad = {
                min = 0.65
            }
        },
        torque = {
            min = 380
        },
        weight = {
            max = 2500
        }
    },
    offerRange = {
        min = 0.3,
        max = 1.0
    }
}, {
    id = "CUST087",
    name = "Riley 'Rugged' Henderson",
    specialties = {"offroad"},
    criteria = {
        performance = {
            offroad = {
                min = 0.8
            }
        },
        torque = {
            min = 390
        },
        weight = {
            max = 2400
        }
    },
    offerRange = {
        min = 0.35,
        max = 1.05
    }
}, {
    id = "CUST088",
    name = "Casey 'Mud Master' Lee",
    specialties = {"offroad"},
    criteria = {
        performance = {
            offroad = {
                min = 0.85
            }
        },
        torque = {
            min = 400
        },
        numAddedParts = {
            min = 2
        },
        weight = {
            max = 2300
        }
    },
    offerRange = {
        min = 0.4,
        max = 1.1
    }
}, {
    id = "CUST089",
    name = "Jordan 'Rock Rover' Kim",
    specialties = {"offroad"},
    criteria = {
        performance = {
            offroad = {
                min = 0.95
            }
        },
        torque = {
            min = 410
        },
        weight = {
            max = 2200
        }
    },
    offerRange = {
        min = 0.45,
        max = 1.15
    }
}, {
    id = "CUST090",
    name = "Morgan 'Dune Dominator' Patel",
    specialties = {"offroad"},
    criteria = {
        performance = {
            offroad = {
                min = 1.0
            }
        },
        torque = {
            min = 420
        },
        weight = {
            max = 2100
        }
    },
    offerRange = {
        min = 0.5,
        max = 1.2
    }
}, {
    id = "CUST091",
    name = "Alex 'Trail Titan' Nguyen",
    specialties = {"offroad"},
    criteria = {
        performance = {
            offroad = {
                min = 1.1
            }
        },
        torque = {
            min = 430
        },
        numAddedParts = {
            min = 3
        },
        weight = {
            max = 2000
        }
    },
    offerRange = {
        min = 0.55,
        max = 1.25
    }
}, {
    id = "CUST092",
    name = "Sam 'Mud Mover' Thompson",
    specialties = {"offroad"},
    criteria = {
        performance = {
            offroad = {
                min = 1.15
            }
        },
        torque = {
            min = 440
        },
        weight = {
            max = 1900
        }
    },
    offerRange = {
        min = 0.6,
        max = 1.3
    }
}, {
    id = "CUST093",
    name = "Jamie 'All-Terrain' Brooks",
    specialties = {"offroad"},
    criteria = {
        performance = {
            offroad = {
                min = 1.2
            }
        },
        torque = {
            min = 450
        },
        weight = {
            max = 1800
        }
    },
    offerRange = {
        min = 0.65,
        max = 1.35
    }
}, {
    id = "CUST094",
    name = "Peyton 'Dirt Devil' Carter",
    specialties = {"offroad"},
    criteria = {
        performance = {
            offroad = {
                min = 1.35
            }
        },
        torque = {
            min = 460
        },
        weight = {
            max = 1700
        }
    },
    offerRange = {
        min = 0.7,
        max = 1.4
    }
}, {
    id = "CUST095",
    name = "Cameron 'Mud Marauder' Lewis",
    specialties = {"offroad"},
    criteria = {
        performance = {
            offroad = {
                min = 1.4
            }
        },
        torque = {
            min = 470
        },
        weight = {
            max = 1600
        }
    },
    offerRange = {
        min = 0.75,
        max = 1.45
    }
}, -- Rally Racers (10)
{
    id = "CUST096",
    name = "Diego 'Rally Rookie' Martinez",
    specialties = {"rally"},
    criteria = {
        performance = {
            rally = {
                min = 0.65
            }
        },
        power = {
            min = 300
        }
    },
    offerRange = {
        min = 0.3,
        max = 1.0
    }
}, {
    id = "CUST097",
    name = "Camila 'Rally Rebel' Silva",
    specialties = {"rally"},
    criteria = {
        performance = {
            rally = {
                min = 0.75
            }
        },
        power = {
            min = 310
        },
        torque = {
            min = 370
        }
    },
    offerRange = {
        min = 0.35,
        max = 1.05
    }
}, {
    id = "CUST098",
    name = "Hector 'Road Warrior' Garcia",
    specialties = {"rally"},
    criteria = {
        performance = {
            rally = {
                min = 0.85
            }
        },
        power = {
            min = 320
        },
        torque = {
            min = 380
        },
        numAddedParts = {
            min = 2
        }
    },
    offerRange = {
        min = 0.4,
        max = 1.1
    }
}, {
    id = "CUST099",
    name = "Ingrid 'Rally Racer' Lund",
    specialties = {"rally"},
    criteria = {
        performance = {
            rally = {
                min = 0.9
            }
        },
        power = {
            min = 330
        },
        torque = {
            min = 390
        }
    },
    offerRange = {
        min = 0.45,
        max = 1.15
    }
}, {
    id = "CUST100",
    name = "Ravi 'Rally Renegade' Singh",
    specialties = {"rally"},
    criteria = {
        performance = {
            rally = {
                min = 0.95
            }
        },
        power = {
            min = 340
        },
        torque = {
            min = 400
        }
    },
    offerRange = {
        min = 0.5,
        max = 1.2
    }
}, {
    id = "CUST101",
    name = "Priya 'Speed Rally' Mehta",
    specialties = {"rally"},
    criteria = {
        performance = {
            rally = {
                min = 1
            }
        },
        power = {
            min = 350
        },
        torque = {
            min = 410
        },
        numAddedParts = {
            min = 3
        }
    },
    offerRange = {
        min = 0.55,
        max = 1.25
    }
}, {
    id = "CUST102",
    name = "Luca 'Turbo Rally' Romano",
    specialties = {"rally"},
    criteria = {
        performance = {
            rally = {
                min = 1.1
            }
        },
        power = {
            min = 360
        },
        torque = {
            min = 420
        }
    },
    offerRange = {
        min = 0.6,
        max = 1.3
    }
}, {
    id = "CUST103",
    name = "Anya 'Rally Rocket' Petrova",
    specialties = {"rally"},
    criteria = {
        performance = {
            rally = {
                min = 1.15
            }
        },
        power = {
            min = 370
        },
        torque = {
            min = 430
        }
    },
    offerRange = {
        min = 0.65,
        max = 1.35
    }
}, {
    id = "CUST104",
    name = "Omar 'Rally Ace' Hassan",
    specialties = {"rally"},
    criteria = {
        performance = {
            rally = {
                min = 1.2
            }
        },
        power = {
            min = 380
        },
        torque = {
            min = 440
        },
        numAddedParts = {
            min = 4
        }
    },
    offerRange = {
        min = 0.7,
        max = 1.4
    }
}, {
    id = "CUST105",
    name = "Lila 'Rally Star' Johnson",
    specialties = {"rally"},
    criteria = {
        performance = {
            rally = {
                min = 1.3
            }
        },
        power = {
            min = 390
        },
        torque = {
            min = 450
        }
    },
    offerRange = {
        min = 0.75,
        max = 1.45
    }
}, -- Crawl Buyers (5)
{
    id = "CUST106",
    name = "Gavin 'Slow and Steady' Brooks",
    specialties = {"crawl"},
    criteria = {
        performance = {
            crawl = {
                min = 0.65
            }
        }
    },
    offerRange = {
        min = 0.2,
        max = 0.9
    }
}, {
    id = "CUST107",
    name = "Megan 'Hill Climber' Davis",
    specialties = {"crawl"},
    criteria = {
        performance = {
            crawl = {
                min = 0.75
            }
        },
        powerPerWeight = {
            min = 0.15
        }
    },
    offerRange = {
        min = 0.25,
        max = 0.95
    }
}, {
    id = "CUST108",
    name = "Omar 'Mountain Climb' Khan",
    specialties = {"crawl"},
    criteria = {
        performance = {
            crawl = {
                min = 0.8
            }
        },
        powerPerWeight = {
            min = 0.16
        }
    },
    offerRange = {
        min = 0.3,
        max = 1.0
    }
}, {
    id = "CUST109",
    name = "Lydia 'Rock Climber' Evans",
    specialties = {"crawl"},
    criteria = {
        performance = {
            crawl = {
                min = 0.95
            }
        },
        powerPerWeight = {
            min = 0.17
        }
    },
    offerRange = {
        min = 0.35,
        max = 1.05
    }
}, {
    id = "CUST110",
    name = "Trevor 'Steady Crawler' Wilson",
    specialties = {"crawl"},
    criteria = {
        performance = {
            crawl = {
                min = 1
            }
        },
        powerPerWeight = {
            min = 0.18
        }
    },
    offerRange = {
        min = 0.4,
        max = 1.1
    }
}, -- Apex Racing Fans (5)
{
    id = "CUST111",
    name = "Violet 'Apex Newbie' Baker",
    specialties = {"apexRacing"},
    criteria = {
        performance = {
            apexRacing = {
                min = 0.75
            }
        },
        power = {
            min = 320
        }
    },
    offerRange = {
        min = 0.3,
        max = 1.0
    }
}, {
    id = "CUST112",
    name = "Dylan 'Apex Driver' Turner",
    specialties = {"apexRacing"},
    criteria = {
        performance = {
            apexRacing = {
                min = 0.85
            }
        },
        power = {
            min = 330
        },
        torque = {
            min = 380
        }
    },
    offerRange = {
        min = 0.35,
        max = 1.05
    }
}, {
    id = "CUST113",
    name = "Hailey 'Apex Ace' Martin",
    specialties = {"apexRacing"},
    criteria = {
        performance = {
            apexRacing = {
                min = 0.9
            }
        },
        power = {
            min = 340
        },
        torque = {
            min = 390
        }
    },
    offerRange = {
        min = 0.4,
        max = 1.1
    }
}, {
    id = "CUST114",
    name = "Eli 'Apex Pro' Mitchell",
    specialties = {"apexRacing"},
    criteria = {
        performance = {
            apexRacing = {
                min = 0.95
            }
        },
        power = {
            min = 350
        },
        torque = {
            min = 400
        }
    },
    offerRange = {
        min = 0.45,
        max = 1.15
    }
}, {
    id = "CUST115",
    name = "Zoe 'Apex Elite' Carter",
    specialties = {"apexRacing"},
    criteria = {
        performance = {
            apexRacing = {
                min = 1
            }
        },
        power = {
            min = 360
        },
        torque = {
            min = 410
        },
        numAddedParts = {
            min = 2
        }
    },
    offerRange = {
        min = 0.5,
        max = 1.2
    }
}, -- Budget Buyers (5)
{
    id = "CUST116",
    name = "Sam 'Thrifty Wheels' Carter",
    specialties = {},
    criteria = {
        value = {
            max = 40000
        },
        weight = {
            max = 2500
        }
    },
    offerRange = {
        min = 0.1,
        max = 0.8
    }
}, {
    id = "CUST117",
    name = "Mia 'Economy Expert' Lee",
    specialties = {},
    criteria = {
        value = {
            max = 35000
        },
        mileage = {
            max = 100000
        }
    },
    offerRange = {
        min = 0.15,
        max = 0.85
    }
}, {
    id = "CUST118",
    name = "Eli 'Budget Buyer' Davis",
    specialties = {},
    criteria = {
        value = {
            max = 30000
        },
        weight = {
            max = 2600
        }
    },
    offerRange = {
        min = 0.1,
        max = 0.75
    }
}, {
    id = "CUST119",
    name = "Ava 'Cost Conscious' Patel",
    specialties = {},
    criteria = {
        value = {
            max = 45000
        },
        mileage = {
            max = 80000
        }
    },
    offerRange = {
        min = 0.1,
        max = 0.9
    }
}, {
    id = "CUST120",
    name = "Noah 'Frugal Rider' Murphy",
    specialties = {},
    criteria = {
        value = {
            max = 38000
        },
        weight = {
            max = 2400
        }
    },
    offerRange = {
        min = 0.15,
        max = 0.85
    }
}, -- Luxury Buyers (5)
{
    id = "CUST121",
    name = "Isabella 'Luxury Seeker' Monroe",
    specialties = {},
    criteria = {
        value = {
            min = 150000
        },
        mileage = {
            max = 30000
        },
        power = {
            min = 400
        },
        taxiDropoffs = {
            min = 3
        }
    },
    offerRange = {
        min = 1.0,
        max = 1.25
    }
}, {
    id = "CUST122",
    name = "Charles 'Prestige Pursuer' Bennett",
    specialties = {},
    criteria = {
        value = {
            min = 200000
        },
        mileage = {
            max = 25000
        },
        power = {
            min = 420
        },
        torque = {
            min = 450
        },
        numRemovedParts = {
            max = 2
        },
        taxiDropoffs = {
            min = 4
        }

    },
    offerRange = {
        min = 1.1,
        max = 1.4
    }
}, {
    id = "CUST123",
    name = "Victoria 'Elite Driver' Foster",
    specialties = {},
    criteria = {
        value = {
            min = 180000
        },
        mileage = {
            max = 20000
        },
        power = {
            min = 410
        },
        taxiDropoffs = {
            min = 20
        }
    },
    offerRange = {
        min = 1.05,
        max = 1.55
    }
}, {
    id = "CUST124",
    name = "Henry 'Luxury Legend' Sinclair",
    specialties = {},
    criteria = {
        value = {
            min = 220000
        },
        mileage = {
            max = 15000
        },
        power = {
            min = 430
        },
        torque = {
            min = 470
        },
        taxiDropoffs = {
            min = 25
        },
        movieRentals = {
            min = 10
        }
    },
    offerRange = {
        min = 1.2,
        max = 1.7
    }
}, {
    id = "CUST125",
    name = "Sophia 'Prestige Pro' Whitman",
    specialties = {},
    criteria = {
        value = {
            min = 250000
        },
        mileage = {
            max = 50
        },
        power = {
            min = 440
        },
        torque = {
            min = 480
        },
        taxiDropoffs = {
            min = 10
        }
    },
    offerRange = {
        min = 1.25,
        max = 1.55
    }
}, -- Classic Collectors (5)
{
    id = "CUST126",
    name = "George 'Vintage Lover' Carter",
    specialties = {},
    criteria = {
        year = {
            max = 1980
        },
        mileage = {
            max = 50000
        },
        value = {
            max = 50000
        }
    },
    offerRange = {
        min = 0.1,
        max = 1.0
    }
}, {
    id = "CUST127",
    name = "Margaret 'Retro Rider' Wilson",
    specialties = {},
    criteria = {
        year = {
            max = 1975
        },
        mileage = {
            max = 60000
        },
        value = {
            max = 55000
        }
    },
    offerRange = {
        min = 0.1,
        max = 1.0
    }
}, {
    id = "CUST128",
    name = "Edward 'Classic Connoisseur' Turner",
    specialties = {},
    criteria = {
        year = {
            max = 1985
        },
        mileage = {
            max = 40000
        },
        value = {
            max = 60000
        }
    },
    offerRange = {
        min = 0.15,
        max = 1.1
    }
}, {
    id = "CUST129",
    name = "Eleanor 'Timeless Treasure' Davis",
    specialties = {},
    criteria = {
        year = {
            max = 1970
        },
        mileage = {
            max = 70000
        },
        value = {
            max = 45000
        }
    },
    offerRange = {
        min = 0.1,
        max = 0.95
    }
}, {
    id = "CUST130",
    name = "Arthur 'Antique Aficionado' Brooks",
    specialties = {},
    criteria = {
        year = {
            max = 1965
        },
        mileage = {
            max = 80000
        },
        value = {
            max = 50000
        }
    },
    offerRange = {
        min = 0.15,
        max = 1.0
    }
}, -- Repair / Utility Buyers (5)
{
    id = "CUST131",
    name = "Ollie 'Fixer Upper' Grant",
    specialties = {},
    criteria = {
        accidents = {
            max = 3
        },
        value = {
            max = 30000
        }
    },
    offerRange = {
        min = 0.1,
        max = 0.8
    }
}, {
    id = "CUST132",
    name = "Linda 'Utility Max' Evans",
    specialties = {},
    criteria = {
        repos = {
            min = 1
        },
        taxiDropoffs = {
            min = 1
        }
    },
    offerRange = {
        min = 0.2,
        max = 1.0
    }
}, {
    id = "CUST133",
    name = "Marcus 'Tow King' Patel",
    specialties = {},
    criteria = {
        repos = {
            min = 2
        },
        power = {
            min = 350
        }
    },
    offerRange = {
        min = 0.2,
        max = 1.1
    }
}, {
    id = "CUST134",
    name = "Candice 'Rental Ready' Lee",
    specialties = {},
    criteria = {
        movieRentals = {
            min = 2
        },
        rep = {
            min = 2
        }
    },
    offerRange = {
        min = 0.2,
        max = 1.05
    }
}, {
    id = "CUST135",
    name = "Bobby 'Mechanic's Choice' Taylor",
    specialties = {},
    criteria = {
        accidents = {
            max = 2
        },
        numRemovedParts = {
            min = 1
        }
    },
    offerRange = {
        min = 0.15,
        max = 0.9
    }
}, -- Additional Mixed Stereotypes (20)
{
    id = "CUST136",
    name = "Dylan 'Urban Racer' Brooks",
    specialties = {"motorsport", "drift"},
    criteria = {
        performance = {
            motorsport = {
                min = 0.7
            },
            drift = {
                min = 0.6
            }
        },
        mileage = {
            max = 50000
        }
    },
    offerRange = {
        min = 0.5,
        max = 1.2
    }
}, {
    id = "CUST137",
    name = "Fiona 'City Slicker' Jenkins",
    specialties = {},
    criteria = {
        mileage = {
            max = 30000
        },
        value = {
            max = 35000
        },
        rep = {
            min = 2
        }
    },
    offerRange = {
        min = 0.2,
        max = 1.0
    }
}, {
    id = "CUST138",
    name = "Gavin 'Suburban Saver' Moore",
    specialties = {},
    criteria = {
        value = {
            max = 40000
        },
        mileage = {
            max = 40000
        },
        power = {
            min = 250
        },
        taxiDropoffs = {
            min = 2
        }
    },
    offerRange = {
        min = 0.15,
        max = 1.1
    }
}, {
    id = "CUST139",
    name = "Hannah 'Weekend Warrior' Adams",
    specialties = {"motorsport"},
    criteria = {
        performance = {
            motorsport = {
                min = 0.65
            }
        },
        power = {
            min = 300
        }
    },
    offerRange = {
        min = 0.3,
        max = 1.0
    }
}, {
    id = "CUST140",
    name = "Ian 'Rugged Rider' Carter",
    specialties = {"offroad"},
    criteria = {
        performance = {
            offroad = {
                min = 0.7
            }
        },
        torque = {
            min = 420
        }
    },
    offerRange = {
        min = 0.3,
        max = 1.1
    }
}, {
    id = "CUST141",
    name = "Jasmine 'Race Rebel' King",
    specialties = {"rally"},
    criteria = {
        performance = {
            rally = {
                min = 0.7
            }
        },
        power = {
            min = 320
        }
    },
    offerRange = {
        min = 0.35,
        max = 1.1
    }
}, {
    id = "CUST142",
    name = "Kevin 'Gearhead' Scott",
    specialties = {},
    criteria = {
        numAddedParts = {
            min = 3
        },
        powerPerWeight = {
            min = 0.15
        }
    },
    offerRange = {
        min = 0.2,
        max = 1.15
    }
}, {
    id = "CUST143",
    name = "Laura 'Precision Pilot' Price",
    specialties = {"apexRacing"},
    criteria = {
        performance = {
            apexRacing = {
                min = 0.65
            }
        },
        power = {
            min = 330
        }
    },
    offerRange = {
        min = 0.3,
        max = 1.1
    }
}, {
    id = "CUST144",
    name = "Michael 'Motor Maven' Ortiz",
    specialties = {"motorsport", "drag"},
    criteria = {
        performance = {
            motorsport = {
                min = 0.75
            },
            drag = {
                min = 0.8
            }
        }
    },
    offerRange = {
        min = 0.4,
        max = 1.2
    }
}, {
    id = "CUST145",
    name = "Natalie 'Neon Nights' Perez",
    specialties = {"drift"},
    criteria = {
        performance = {
            drift = {
                min = 0.7
            }
        },
        power = {
            min = 320
        }
    },
    offerRange = {
        min = 0.35,
        max = 1.15
    }
}, {
    id = "CUST146",
    name = "Oliver 'Offroad Outlaw' Brooks",
    specialties = {"offroad"},
    criteria = {
        performance = {
            offroad = {
                min = 0.75
            }
        },
        torque = {
            min = 430
        }
    },
    offerRange = {
        min = 0.4,
        max = 1.2
    }
}, {
    id = "CUST147",
    name = "Paige 'Performance Princess' Rivera",
    specialties = {"motorsport", "apexRacing"},
    criteria = {
        performance = {
            motorsport = {
                min = 0.7
            },
            apexRacing = {
                min = 0.65
            }
        }
    },
    offerRange = {
        min = 0.4,
        max = 1.2
    }
}, {
    id = "CUST148",
    name = "Quentin 'Quick Shift' Foster",
    specialties = {"drag"},
    criteria = {
        performance = {
            drag = {
                min = 0.85
            }
        },
        power = {
            min = 340
        }
    },
    offerRange = {
        min = 0.35,
        max = 1.15
    }
}, {
    id = "CUST149",
    name = "Rebecca 'Road Rebel' Kim",
    specialties = {"rally"},
    criteria = {
        performance = {
            rally = {
                min = 0.75
            }
        },
        power = {
            min = 330
        }
    },
    offerRange = {
        min = 0.4,
        max = 1.2
    }
}, {
    id = "CUST150",
    name = "Steven 'Speed Slinger' Hughes",
    specialties = {"motorsport"},
    criteria = {
        performance = {
            motorsport = {
                min = 0.8
            }
        },
        power = {
            min = 350
        }
    },
    offerRange = {
        min = 0.45,
        max = 1.25
    }
}, {
    id = "CUST151",
    name = "Tara 'Turbo Tactician' Murphy",
    specialties = {"drag", "motorsport"},
    criteria = {
        performance = {
            drag = {
                min = 0.8
            },
            motorsport = {
                min = 0.7
            }
        }
    },
    offerRange = {
        min = 0.4,
        max = 1.2
    }
}, {
    id = "CUST152",
    name = "Ulysses 'Urban Underground' Reed",
    specialties = {},
    criteria = {
        rep = {
            min = 4
        },
        value = {
            max = 60000
        }
    },
    offerRange = {
        min = 0.3,
        max = 1.0
    }
}, {
    id = "CUST153",
    name = "Vera 'Vintage Vixen' Ortiz",
    specialties = {"classic"},
    criteria = {
        year = {
            max = 1980
        },
        mileage = {
            max = 60000
        }
    },
    offerRange = {
        min = 0.2,
        max = 1.0
    }
}, {
    id = "CUST154",
    name = "Wade 'Wheel Wizard' Simmons",
    specialties = {"motorsport", "drift"},
    criteria = {
        performance = {
            motorsport = {
                min = 0.75
            },
            drift = {
                min = 0.65
            }
        }
    },
    offerRange = {
        min = 0.35,
        max = 1.15
    }
}, {
    id = "CUST155",
    name = "Xena 'Xtreme Xplorer' Reed",
    specialties = {"offroad", "rally"},
    criteria = {
        performance = {
            offroad = {
                min = 0.8
            },
            rally = {
                min = 0.75
            }
        }
    },
    offerRange = {
        min = 0.4,
        max = 1.2
    }
}, {
    id = "CUST156",
    name = "Taxi Tycoon Tommy",
    specialties = {},
    criteria = {
        taxiDropoffs = {
            min = 50
        },
        mileage = {
            max = 100000
        } -- Prefers lower mileage for reliability
    },
    offerRange = {
        min = 0.3,
        max = 1.25
    }
}, {
    id = "CUST157",
    name = "Repo Raider Randy",
    specialties = {},
    criteria = {
        repos = {
            min = 3
        }
    },
    offerRange = {
        min = 0.25,
        max = 1.15
    }
}, {
    id = "CUST158",
    name = "Reputation Rex",
    specialties = {},
    criteria = {
        rep = {
            min = 8
        },
        arrests = {
            max = 0
        },
        tickets = {
            max = 0
        },
        taxiDropoffs = {
            min = 2
        }
    },
    offerRange = {
        min = 0.4,
        max = 1.3
    }
}, {
    id = "CUST159",
    name = "Movie Maven Mia",
    specialties = {},
    criteria = {
        movieRentals = {
            min = 5
        }
    },
    offerRange = {
        min = 0.35,
        max = 1.25
    }
}, {
    id = "CUST160",
    name = "Evasion Expert Evan",
    specialties = {},
    criteria = {
        evades = {
            min = 3
        },
        arrests = {
            max = 0
        }
    },
    offerRange = {
        min = 0.4,
        max = 1.2
    }
}, {
    id = "CUST161",
    name = "Ticketless Tina",
    specialties = {},
    criteria = {
        tickets = {
            max = 2
        },
        taxiDropoffs = {
            min = 3
        }
    },
    offerRange = {
        min = 0.3,
        max = 1.1
    }
}, {
    id = "CUST162",
    name = "Accident Avoider Andy",
    specialties = {},
    criteria = {
        accidents = {
            max = 0
        },
        rep = {
            min = 4
        }
    },
    offerRange = {
        min = 0.35,
        max = 1.15
    }
}, {
    id = "CUST163",
    name = "Clean Record Carla",
    specialties = {},
    criteria = {
        arrests = {
            max = 0
        },
        tickets = {
            max = 0
        },
        mileage = {
            max = 100000
        }
    },
    offerRange = {
        min = 0.5,
        max = 1.15
    }
}, {
    id = "CUST164",
    name = "Tow Truck Tyler",
    specialties = {},
    criteria = {
        repos = {
            min = 3
        }
    },
    offerRange = {
        min = 0.25,
        max = 1.2
    }
}, {
    id = "CUST165",
    name = "Cinema Car Cindy",
    specialties = {},
    criteria = {
        movieRentals = {
            min = 3
        }
    },
    offerRange = {
        min = 0.3,
        max = 1.2
    }
}, {
    id = "CUST166",
    name = "Reputation Royalty Rob",
    specialties = {},
    criteria = {
        rep = {
            min = 10
        }
    },
    offerRange = {
        min = 0.45,
        max = 1.35
    }
}, {
    id = "CUST167",
    name = "Evade Elite Elisa",
    specialties = {},
    criteria = {
        evades = {
            min = 4
        },
        arrests = {
            max = 0
        }
    },
    offerRange = {
        min = 0.4,
        max = 1.3
    }
}, {
    id = "CUST168",
    name = "Hustle Henry",
    specialties = {},
    criteria = {
        taxiDropoffs = {
            min = 100
        }
    },
    offerRange = {
        min = 0.5,
        max = 1.4
    }
}, {
    id = "CUST169",
    name = "Bargain Betty",
    specialties = {},
    criteria = {
        value = {
            max = 50000
        },
        tickets = {
            max = 3
        }
    },
    offerRange = {
        min = 0.2,
        max = 1.0
    }
}, {
    id = "CUST170",
    name = "Tow Master Marcus",
    specialties = {},
    criteria = {
        repos = {
            min = 5
        }
    },
    offerRange = {
        min = 0.3,
        max = 1.2
    }
}, {
    id = "CUST171",
    name = "Movie Mogul Max",
    specialties = {},
    criteria = {
        movieRentals = {
            min = 7
        }
    },
    offerRange = {
        min = 0.5,
        max = 1.4
    }
}, {
    id = "CUST172",
    name = "Ride Reputation Rita",
    specialties = {},
    criteria = {
        rep = {
            min = 6
        }
    },
    offerRange = {
        min = 0.35,
        max = 1.2
    }
}, {
    id = "CUST173",
    name = "Stealthy Steve",
    specialties = {},
    criteria = {
        evades = {
            min = 5
        },
        arrests = {
            max = 0
        }
    },
    offerRange = {
        min = 0.45,
        max = 1.3
    }
}, {
    id = "CUST174",
    name = "Ticket Tamer Tara",
    specialties = {},
    criteria = {
        tickets = {
            max = 1
        },
        mileage = {
            max = 10000
        }
    },
    offerRange = {
        min = 0.3,
        max = 1.1
    }
}, {
    id = "CUST175",
    name = "Balanced Bob",
    specialties = {},
    criteria = {
        rep = {
            min = 4
        },
        taxiDropoffs = {
            min = 10
        },
        evades = {
            min = 1
        },
        movieRentals = {
            min = 1
        },
        repos = {
            min = 1
        }
    },
    offerRange = {
        min = 0.3,
        max = 1.2
    }
}, {
    id = "CUST175",
    name = "Balanced Bob",
    specialties = {},
    criteria = {
        rep = {
            min = 3
        },
        taxiDropoffs = {
            min = 10
        },
        evades = {
            min = 1
        },
        movieRentals = {
            min = 1
        },
        repos = {
            min = 1
        }
    },
    offerRange = {
        min = 1.0,
        max = 1.4
    }
}, {
    id = "CUST176",
    name = "Oval Ace Owen",
    specialties = {"oval"},
    criteria = {
        performance = {
            oval = { min = 0.9 }
        },
        rep = { min = 2 },
        tickets = { max = 2 }
    },
    offerRange = { min = 1.1, max = 1.25 }
}, {
    id = "CUST177",
    name = "Mud Queen Maggie",
    specialties = {"mud"},
    criteria = {
        performance = {
            mud = { min = 0.85 }
        },
        evades = { min = 1 }
    },
    offerRange = { min = 1.0, max = 1.3 }
}, {
    id = "CUST178",
    name = "Extreme Mudder Eddie",
    specialties = {"mud", "extremeMud"},
    criteria = {
        performance = {
            mud = { min = 0.8 },
            extremeMud = { min = 0.8 }
        },
        taxiDropoffs = { min = 5 }
    },
    offerRange = { min = 1.15, max = 1.35 }
}, {
    id = "CUST179",
    name = "Banked Turn Betty",
    specialties = {"oval"},
    criteria = {
        performance = {
            oval = { min = 0.95 }
        },
        rep = { min = 3 },
        movieRentals = { min = 1 }
    },
    offerRange = { min = 1.2, max = 1.4 }
}, {
    id = "CUST180",
    name = "Swamp Specialist Sam",
    specialties = {"extremeMud"},
    criteria = {
        performance = {
            extremeMud = { min = 0.9 }
        },
        repos = { min = 2 }
    },
    offerRange = { min = 1.05, max = 1.3 }
}, {
    id = "CUST181",
    name = "Dirt Track Dave",
    specialties = {"oval", "mud"},
    criteria = {
        performance = {
            oval = { min = 0.7 },
            mud = { min = 0.75 }
        },
        taxiDropoffs = { min = 3 }
    },
    offerRange = { min = 0.6, max = 1.2 }
}, {
    id = "CUST182",
    name = "Mud Marathon Mia",
    specialties = {"mud"},
    criteria = {
        performance = {
            mud = { min = 0.95 }
        },
        mileage = { max = 50000 }
    },
    offerRange = { min = 0.95, max = 1.45 }
}, {
    id = "CUST183",
    name = "Oval Outlaw Oscar",
    specialties = {"oval"},
    criteria = {
        performance = {
            oval = { min = 1.0 }
        },
        tickets = { min = 2 }
    },
    offerRange = { min = 0.85, max = 1.35 }
}, {
    id = "CUST184",
    name = "Bog Beast Brenda",
    specialties = {"extremeMud"},
    criteria = {
        performance = {
            extremeMud = { min = 0.85 }
        },
        mileage = { max = 200000 }
    },
    offerRange = { min = 1.1, max = 1.35 }
}, {
    id = "CUST185",
    name = "Clay Track Carl",
    specialties = {"oval", "mud"},
    criteria = {
        performance = {
            oval = { min = 0.8 },
            mud = { min = 0.8 },
            offroad = { min = 0.8 }
        },
        rep = { min = 1 }
    },
    offerRange = { min = 1.0, max = 1.3 }
}, {
    id = "CUST186",
    name = "Mud Slinger Max",
    specialties = {"mud"},
    criteria = {
        performance = {
            mud = { min = 0.9 }
        },
        accidents = { min = 1 }
    },
    offerRange = { min = 1.15, max = 1.4 }
}, {
    id = "CUST187",
    name = "Extreme Endurance Eva",
    specialties = {"extremeMud"},
    criteria = {
        performance = {
            extremeMud = { min = 0.75 }
        },
        mileage = { max = 100000 }
    },
    offerRange = { min = 0.95, max = 1.2 }
}, {
    id = "CUST188",
    name = "High Bank Hank",
    specialties = {"oval"},
    criteria = {
        performance = {
            oval = { min = 0.85 }
        },
        powerPerWeight = { min = 0.2 }
    },
    offerRange = { min = 0.85, max = 1.3 }
}, {
    id = "CUST189",
    name = "Mud & Movies Marty",
    specialties = {"mud"},
    criteria = {
        performance = {
            mud = { min = 0.7 }
        },
        movieRentals = { min = 2 }
    },
    offerRange = { min = 0.8, max = 1.35 }
}, {
    id = "CUST190",
    name = "Oval Purist Pete",
    specialties = {"oval"},
    criteria = {
        performance = {
            oval = { min = 0.95 }
        },
        numAddedParts = { max = 5 }
    },
    offerRange = { min = 0.85, max = 1.65 }
}, {
    id = "CUST191",
    name = "Bog Navigator Nate",
    specialties = {"extremeMud"},
    criteria = {
        performance = {
            extremeMud = { min = 0.9 }
        },
        taxiDropoffs = { min = 5 }
    },
    offerRange = { min = 1.05, max = 1.9 }
}, {
    id = "CUST192",
    name = "Dual Surface Dana",
    specialties = {"oval", "mud"},
    criteria = {
        performance = {
            oval = { min = 0.75 },
            mud = { min = 0.8 }
        },
        rep = { min = 2 }
    },
    offerRange = { min = 1.0, max = 1.3 }
}, {
    id = "CUST193",
    name = "Mud Modder Mike",
    specialties = {"mud"},
    criteria = {
        performance = {
            mud = { min = 0.85 }
        },
        numAddedParts = { min = 8 }
    },
    offerRange = { min = 1.1, max = 1.35 }
}, {
    id = "CUST194",
    name = "Extreme Enthusiast Erin",
    specialties = {"extremeMud"},
    criteria = {
        performance = {
            extremeMud = { min = 1.0 }
        },
        rep = { min = 4 }
    },
    offerRange = { min = 1.0, max = 1.55 }
}, {
    id = "CUST195",
    name = "Oval Rookie Rachel",
    specialties = {"oval"},
    criteria = {
        performance = {
            oval = { min = 0.6 }
        },
        mileage = { max = 80000 }
    },
    offerRange = { min = 0.9, max = 1.1 }
}, {
    id = "CUST196",
    name = "Mud Taxi Terry",
    specialties = {"mud"},
    criteria = {
        performance = {
            mud = { min = 0.7 }
        },
        taxiDropoffs = { min = 10 }
    },
    offerRange = { min = 0.95, max = 1.2 }
}, {
    id = "CUST197",
    name = "Bog Champion Charlie",
    specialties = {"extremeMud"},
    criteria = {
        performance = {
            extremeMud = { min = 0.95 }
        },
        evades = { min = 2 }
    },
    offerRange = { min = 1.05, max = 1.45 }
}, {
    id = "CUST198",
    name = "Oval & Road Ollie",
    specialties = {"oval"},
    criteria = {
        performance = {
            oval = { min = 0.8 }
        },
        power = { min = 300 }
    },
    offerRange = { min = 1.15, max = 1.35 }
}, {
    id = "CUST199",
    name = "Muddy Mechanic Mo",
    specialties = {"mud"},
    criteria = {
        performance = {
            mud = { min = 0.75 }
        },
        numRemovedParts = { min = 3 }
    },
    offerRange = { min = 0.85, max = 1.15 }
}, {
    id = "CUST200",
    name = "Extreme Collector Xander",
    specialties = {"extremeMud"},
    criteria = {
        performance = {
            extremeMud = { min = 0.85 }
        },
        value = { max = 75000 }
    },
    offerRange = { min = 1.0, max = 1.3 }
}
}

local function getInterestedCustomers(vehicleData)
    local interestedCustomers = {}
    for _, customer in ipairs(customers) do
        local customerInterested = true
        local interestValue = 0
        local maxCustomerInterest = 0

        for criterionName, criterionValue in pairs(customer.criteria) do
            local criterionMaxInterest = 0

            if criterionName == "performance" then
                criterionMaxInterest = table.getn(criterionValue)
                for performanceType, performanceCriteria in pairs(criterionValue) do
                    local performanceValue = nil
                    if vehicleData.performanceValues and vehicleData.performanceValues[performanceType] then
                        for _, perfEntry in ipairs(vehicleData.performanceValues[performanceType]) do
                            performanceValue = perfEntry.performance
                            break
                        end
                    end

                    -- 1. Check for max = 0 (hard rejection) *only if* performanceValue exists
                    if performanceValue ~= nil and performanceCriteria.max ~= nil and performanceCriteria.max == 0 then
                        customerInterested = false
                        break
                    end

                    -- 2.  Handle nil performanceValue when there's a min
                    if performanceValue == nil then
                        if performanceCriteria.min ~= nil then
                            customerInterested = false
                            break
                        end
                    end

                    -- 3. Now do the regular min/max checks, only if performanceValue is not nil
                    if performanceValue ~= nil then
                        if performanceCriteria.min ~= nil and performanceValue < performanceCriteria.min then
                            customerInterested = false
                            break
                        end
                        if performanceCriteria.max ~= nil and performanceValue > performanceCriteria.max then
                            customerInterested = false
                            break
                        end

                        -- Calculate interest
                        if customerInterested then
                            if performanceCriteria.max ~= nil and performanceCriteria.min ~= nil then
                                local range = performanceCriteria.max - performanceCriteria.min
                                if range > 0 then
                                    interestValue = interestValue + (performanceValue - performanceCriteria.min) / range
                                elseif performanceValue >= performanceCriteria.min and performanceValue <=
                                    performanceCriteria.max then
                                    interestValue = interestValue + 1
                                end
                            elseif performanceCriteria.max ~= nil then
                                interestValue = interestValue +
                                                    math.max(0, 1 - (performanceValue / performanceCriteria.max))
                            elseif performanceCriteria.min ~= nil then
                                interestValue = interestValue +
                                                    math.min(1, performanceValue / (performanceCriteria.min * 3))
                            else
                                interestValue = interestValue + 0.5
                            end
                        end
                    end
                end
            elseif criterionName == "power" or criterionName == "torque" or criterionName == "powerPerWeight" or
                criterionName == "rep" or criterionName == "numAddedParts" or criterionName == "evades" or criterionName ==
                "movieRentals" or criterionName == "repos" or criterionName == "taxiDropoffs" then
                -- Logic for "higher is better" criteria
                criterionMaxInterest = 1
                local criterionData = tonumber(vehicleData[criterionName] or 0)

                if criterionValue.min ~= nil and criterionData < criterionValue.min then
                    customerInterested = false
                    break
                end
                -- Calculate interest for "higher is better" (similar logic for all in this group)
                if customerInterested then
                    if criterionValue.min ~= nil then
                        interestValue = interestValue + math.min(1, criterionData / (criterionValue.min * 3))
                    else
                        interestValue = interestValue + 0.5
                    end
                end

            elseif criterionName == "mileage" or criterionName == "numRemovedParts" or criterionName == "value" or
                criterionName == "weight" or criterionName == "arrests" or criterionName == "tickets" or criterionName ==
                "accidents" then
                -- Logic for "lower is better" criteria
                criterionMaxInterest = 1
                local criterionData = tonumber(vehicleData[criterionName] or 0)

                if criterionValue.max ~= nil and criterionData > criterionValue.max then
                    customerInterested = false
                    break
                end
                -- Calculate interest for "lower is better" (similar logic for all in this group)
                if customerInterested then
                    if criterionValue.max ~= nil then
                        if criterionValue.max == 0 and criterionData == 0 then
                            interestValue = interestValue + 1 -- 100% interest if max is 0 and data is 0
                        else
                            interestValue = interestValue + math.max(0, 1 - (criterionData / criterionValue.max))
                        end
                    else
                        interestValue = interestValue + 0.5
                    end
                end

            elseif criterionName == "year" then
                criterionMaxInterest = 1
                local year = tonumber(vehicleData.year) or 0 -- Default to 0 if nil

                if criterionValue.min ~= nil and year < criterionValue.min then
                    customerInterested = false
                    break -- Year below minimum
                end
                if criterionValue.max ~= nil and year > criterionValue.max then
                    customerInterested = false
                    break -- Year above maximum
                end

                -- Calculate interest
                if customerInterested then
                    if criterionValue.min ~= nil and criterionValue.max ~= nil then
                        -- Both min and max exist: interest peaks in the middle
                        local midPoint = (criterionValue.min + criterionValue.max) / 2
                        local range = (criterionValue.max - criterionValue.min) / 2
                        if range > 0 then
                            interestValue = interestValue + (1 - math.abs(year - midPoint) / range)
                        elseif year >= criterionValue.min and year <= criterionValue.max then
                            interestValue = interestValue + 1
                        end
                    elseif criterionValue.min ~= nil then
                        -- Only min exists: higher year = higher interest (capped at 1)
                        interestValue = interestValue + math.min(1, year / criterionValue.min)
                    elseif criterionValue.max ~= nil then
                        -- Only max exists: lower year = higher interest
                        interestValue = interestValue + math.max(0, 1 - (year / criterionValue.max))
                    else
                        -- Neither min nor max: neutral interest
                        interestValue = interestValue + 0.5
                    end
                end
            else
                -- Handle unrecognized criteria (optional - for robustness)
                -- print("Warning: Unrecognized customer criterion:", criterionName)
                -- You could choose to set customerInterested = false or assign neutral interest here
                interestValue = interestValue + 0.5 -- Neutral interest for unknown criteria
                criterionMaxInterest = 1 -- Assign some max interest so it doesn't break normalization
            end

            if customerInterested then
                maxCustomerInterest = maxCustomerInterest + criterionMaxInterest
            end

            if not customerInterested then
                break
            end
        end

        local normalizedInterest = 0
        if customerInterested and maxCustomerInterest > 0 then
            normalizedInterest = interestValue / maxCustomerInterest
        end

        if customerInterested then
            table.insert(interestedCustomers, {
                id = customer.id,
                name = customer.name,
                offerRange = customer.offerRange,
                interest = normalizedInterest
            })
        end
    end
    -- Sort customers by interest value in descending order
    table.sort(interestedCustomers, function(a, b)
        return a.interest > b.interest
    end)
    return interestedCustomers
end

M.getInterestedCustomers = getInterestedCustomers

return M
