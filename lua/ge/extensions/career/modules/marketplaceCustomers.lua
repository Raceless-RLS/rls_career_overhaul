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
        mileage = {
            max = 100
        },
        numAddedParts = {
            min = 1,
            max = 10
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
            min = 1,
            max = 12
        }
    },
    offerRange = {
        min = 0.45,
        max = 1.25
    }
}, {
    id = "CUST003",
    name = "Ava 'Apex' Sharma",
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
            min = 400
        },
        mileage = {
            max = 120
        }
    },
    offerRange = {
        min = 0.4,
        max = 1.2
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
        max = 1.3
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
        max = 1.25
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
        max = 1.3
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
        },
        mileage = {
            max = 150
        }
    },
    offerRange = {
        min = 0.55,
        max = 1.25
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
        max = 1.25
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
        mileage = {
            max = 100
        },
        value = {
            max = 70000
        }
    },
    offerRange = {
        min = 0.4,
        max = 1.35
    }
}, {
    id = "CUST010",
    name = "Ethan 'Rally Enthusiast' Martinez",
    specialties = {"rally"},
    criteria = {
        performance = {
            rally = {
                min = 0.6,
                max = 1.0
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
                min = 0.6
            }
        },
        mileage = {
            max = 150
        },
        numRemovedParts = {
            max = 10
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
                min = 0.45
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
                min = 0.6,
                max = 1.0
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
                min = 0.65
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
                min = 0.5
            },
            motorsport = {
                min = 0.6
            },
            rally = {
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
            max = 120
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
        max = 1.35
    }

}, {
    id = "CUST017",
    name = "Amelia 'Power Seeker' Hill",
    specialties = {},
    criteria = {
        power = {
            min = 320
        },
        torque = {
            min = 400
        },
        numAddedParts = {
            min = 3
        },
        numRemovedParts = {
            max = 8
        },
        weight = {
            max = 2000
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
            max = 2000
        },
        numAddedParts = {
            min = 1,
            max = 12
        },
        numRemovedParts = {
            max = 12
        }
    },
    offerRange = {
        min = 0.35,
        max = 1.3
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
        max = 1.1
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
        mileage = {
            max = 100
        },
        value = {
            max = 75000
        }
    },
    offerRange = {
        min = 0.25,
        max = 1.35
    }
}, -- Unlimited Customers (criteria defined only as minimums)
{
    id = "CUST021",
    name = "William 'Drift Expert' Wright",
    specialties = {"drift"},
    criteria = {
        performance = {
            drift = {
                min = 0.75
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
                min = 0.65
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
                min = 0.7
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
                min = 0.75
            } -- no max specified
        },
        torque = {
            min = 400
        }
    },
    offerRange = {
        min = 0.25,
        max = 1.35
    }

}, {
    id = "CUST025",
    name = "Benjamin 'Rally Champ' Gray",
    specialties = {"rally"},
    criteria = {
        performance = {
            rally = {
                min = 0.75
            } -- no max specified
        },
        power = {
            min = 500
        }
    },
    offerRange = {
        min = 0.15,
        max = 1.35
    }

}, {
    id = "CUST026",
    name = "Victoria 'Versatile' Hayes",
    specialties = {"drift", "motorsport", "drag", "offroad", "rally", "crawl", "apexRacing"},
    criteria = {
        performance = {
            drift = {
                min = 0.5
            },
            motorsport = {
                min = 0.6
            },
            drag = {
                min = 0.6
            },
            offroad = {
                min = 0.5
            },
            rally = {
                min = 0.6
            },
            crawl = {
                min = 0.4
            },
            apexRacing = {
                min = 0.65
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
        max = 1.25
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
},
{
    id = "CUST031",
    name = "Belasco Auto",
    specialties = {},  -- general car dealership
    criteria = {
      mileage = { max = 45000 },      -- quality used vehicles (low miles)
      value   = { max = 65000 },   -- affordable, quality vehicles
      power   = { min = 320 },
      torque  = { min = 400 }
    },
    offerRange = { min = 0.3, max = 1.05 }  -- no range provided → default
  },
  -- Jefferson Motors (sells Custom American cars)
  {
    id = "CUST032",
    name = "Jefferson Motors",
    specialties = {"motorsport"},
    criteria = {
      power   = { min = 320 },
      torque  = { min = 400 },
      mileage = { max = 1200 },
      value   = { max = 165000 }
    },
    offerRange = { min = 0.05, max = 1.05 }
  },
  -- Rich's Motor Company (sells prestige, high–quality vehicles)
  {
    id = "CUST033",
    name = "Rich's Motor Company",
    specialties = {"apexRacing"},
    criteria = {
      value   = { min = 120000 },   -- they require higher–priced, prestigious vehicles
      mileage = { max = 1000 },
      power   = { min = 350 },
      torque  = { min = 420 }
    },
    offerRange = { min = 0.15, max = 1.05 }
  },
  -- Quarryside Auto Sales (sells used trucks and vans)
  {
    id = "CUST034",
    name = "Quarryside Auto Sales",
    specialties = {"crawl"},
    criteria = {
      performance = { crawl = { min = 0.5 } },
      power   = { min = 350 },
      torque  = { min = 450 },
      mileage = { max = 160000 },
      value   = { max = 65000 }
    },
    offerRange = { min = 0.75, max = 1.25 }
  },
  -- Smash Rollers (FrameDealership – starting builds)
  {
    id = "CUST035",
    name = "Smash Rollers",
    specialties = {},  -- a base for builds; not focused on performance
    criteria = {
      value   = { max = 50000 },
      mileage = { min = 100000 },
      power   = { max = 400 },
      torque  = { max = 500 }
    },
    offerRange = { min = 0.2, max = 0.75 }
  },
  -- Rocking Rally (sells rally vehicles)
  {
    id = "CUST036",
    name = "Rocking Rally",
    specialties = {"rally"},
    criteria = {
      performance = { rally = { min = 0.6 } },
      power       = { min = 320 },
      torque      = { min = 400 },
      mileage     = { max = 150000 }
    },
    offerRange = { min = 0.7, max = 1.3 }
  },
  -- Clockwise Drag Racing (sells drag vehicles)
  {
    id = "CUST037",
    name = "Clockwise Drag Racing",
    specialties = {"drag"},
    criteria = {
      performance = { drag = { min = 1.2 } },
      power       = { min = 600 },
      torque      = { min = 800 },
      mileage     = { max = 200000 }

    },
    offerRange = { min = 0.25, max = 1.35 }
  },
  -- DriftGear Dealer (sells drift vehicles)
  {
    id = "CUST038",
    name = "DriftGear Dealer",
    specialties = {"drift"},
    criteria = {
      performance = { drift = { min = 0.75 } },
      power       = { min = 300 },
      torque      = { min = 400 },
      mileage     = { max = 200000 }
    },
    offerRange = { min = 0.25, max = 1.25 }
  },
  -- Gizamn's Rod Shop (sells modified/drift vehicles)
  {
    id = "CUST039",
    name = "Gizamn's Rod Shop",
    specialties = {"drag"},
    criteria = {
      performance = { drag = { min = 1 } },
      power       = { min = 600 },
      torque      = { min = 800 },
      mileage     = { max = 100000 }
    },
    offerRange = { min = 0.25, max = 1.25 }
  },
  -- TJs Offroad World (sells offroad vehicles)
  {
    id = "CUST040",
    name = "TJs Offroad World",
    specialties = {"offroad"},
    criteria = {
      performance = { offroad = { min = 0.75 } },
      power       = { min = 320 },
      torque      = { min = 400 },
      mileage     = { max = 150000 }
    },
    offerRange = { min = 0.3, max = 1.3 }
  },
  -- Trusted Auto Sales (sells discounted cars)
  {
    id = "CUST041",
    name = "Trusted Auto Sales",
    specialties = {},
    criteria = {
      value   = { max = 65000 },
      mileage = { max = 1000000 },
      power   = { min = 100 },
      torque  = { min = 100 }
    },
    offerRange = { min = 0.15, max = 0.8 }
  },
  {
    id = "CUST042",
    name = "Joe's Junk",
    specialties = {},  -- no performance focus
    criteria = {
      value   = { max = 45000 },
      mileage = { max = 450000 },
      power   = { min = 100 },
      torque  = { min = 100 }
    },
    offerRange = { min = 0.1, max = 0.75 }
  },
  -- Fast Automotive (sells fast race cars)
  {
    id = "CUST043",
    name = "Fast Automotive",
    specialties = {"motorsport"},
    criteria = {
      performance = { motorsport = { min = 0.6 } },
      power       = { min = 320 },
      torque      = { min = 400 },
      mileage     = { max = 30000 }
    },
    offerRange = { min = 0.15, max = 1.3 }
  },
  {
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
        max = 1.35
    }
},
{
  id = "CUST045",
  name = "Phil 'Builds' Evans",
  specialties = {},
  criteria = {
      mileage = {
          max = 400000
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
      min = 0.65,
      max = 1.25
  }
},
{
    id = "CUST046",
    name = "Meetup Maven Mia",
    specialties = {},  -- No specific performance focus
    criteria = {
        rep = { min = 3.5 },  -- Requires high rep
        numAddedParts = { min = 5 },
        value = { max = 100000 }
    },
    offerRange = { min = 0.8, max = 1.4 }  -- Higher offer range
},
{
    id = "CUST047",
    name = "Showoff King Kai",
    specialties = {}, -- No specific performance focus
    criteria = {
        rep = { min = 5 },  -- Very high rep requirement
        power = { min = 450 },
        torque = {min = 500},
        value = { min = 150000 },
        numAddedParts = { min = 2 }
    },
    offerRange = { min = 0.9, max = 1.35 } -- Even higher offer range
},
{
    id = "CUST048",
    name = "Shady Shane",
    specialties = {}, -- No specific performance focus
    criteria = {
        rep = { min = 0.3 },  -- Very high rep requirement
        power = { min = 250},
        torque = {min = 300}
    },
    offerRange = { min = 0.15, max = 1.25 }
},
{
    id = "CUST049",
    name = "Cruise Collective",
    specialties = {}, -- No specific performance focus
    criteria = {
        rep = { min = 10 },  -- Very high rep requirement
        powerPerWeight = { max = 0.25},
        numAddedParts = { min = 2 }
    },
    offerRange = { min = 0.85, max = 1.45 }
},
{
    id = "CUST050",
    name = "Elden's Classics",
    specialties = {}, -- No specific performance focus
    criteria = {
        performance = {
            drag = {
                max = 0
            }
        },
        numAddedParts = { max = 1 },
        year = { max = 2000 },
        mileage = { max = 100 },
        value = { max = 100000 }
    },
    offerRange = { min = 0.1, max = 1.25 }
},
{
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
    offerRange = { min = 0.45, max = 1.5 }
    },
    {
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
                                elseif performanceValue >= performanceCriteria.min and performanceValue <= performanceCriteria.max then
                                    interestValue = interestValue + 1
                                end
                            elseif performanceCriteria.max ~= nil then
                                interestValue = interestValue + math.max(0, 1 - (performanceValue / performanceCriteria.max))
                            elseif performanceCriteria.min ~= nil then
                                interestValue = interestValue + math.min(1, performanceValue / (performanceCriteria.min * 3))
                            else
                                interestValue = interestValue + 0.5
                            end
                        end
                    end
                end
            elseif criterionName == "power" then
                criterionMaxInterest = 1
                local power = tonumber(vehicleData.power)
                if criterionValue.min ~= nil and power < criterionValue.min then
                    customerInterested = false
                    break -- Power below minimum
                end
                if criterionValue.max ~= nil and power > criterionValue.max then
                    customerInterested = false
                    break -- Power above maximum
                end
                -- Calculate interest for power (higher is better, closer to max)
                if customerInterested then
                    if criterionValue.max ~= nil and criterionValue.min ~= nil then
                        local range = criterionValue.max - criterionValue.min
                        if range > 0 then
                            interestValue = interestValue + (power - criterionValue.min) / range
                        elseif power >= criterionValue.min and power <= criterionValue.max then
                            interestValue = interestValue + 1
                        end
                    elseif criterionValue.max ~= nil then -- only max specified, lower is better
                        interestValue = interestValue + math.max(0, 1 - (power / criterionValue.max))
                    elseif criterionValue.min ~= nil then -- only min specified, higher is better
                        interestValue = interestValue + math.min(1, power / (criterionValue.min * 3)) -- Cap at 1 when 3x min
                    else
                        interestValue = interestValue + 0.5 -- No min/max, neutral interest
                    end
                end
            elseif criterionName == "torque" then
                criterionMaxInterest = 1
                local torque = tonumber(vehicleData.torque)
                if criterionValue.min ~= nil and torque < criterionValue.min then
                    customerInterested = false
                    break -- Torque below minimum
                end
                if criterionValue.max ~= nil and torque > criterionValue.max then
                    customerInterested = false
                    break -- Torque above maximum
                end
                -- Calculate interest for torque (higher is better, closer to max)
                if customerInterested then
                    if criterionValue.max ~= nil and criterionValue.min ~= nil then
                        local range = criterionValue.max - criterionValue.min
                        if range > 0 then
                            interestValue = interestValue + (torque - criterionValue.min) / range
                        elseif torque >= criterionValue.min and torque <= criterionValue.max then
                            interestValue = interestValue + 1
                        end
                    elseif criterionValue.max ~= nil then -- only max specified, lower is better
                        interestValue = interestValue + math.max(0, 1 - (torque / criterionValue.max))
                    elseif criterionValue.min ~= nil then -- only min specified, higher is better
                        interestValue = interestValue + math.min(1, torque / (criterionValue.min * 3)) -- Cap at 1 when 3x min
                    else
                        interestValue = interestValue + 0.5 -- No min/max, neutral interest
                    end
                end
            elseif criterionName == "mileage" then
                criterionMaxInterest = 1
                local mileage = tonumber(vehicleData.mileage)
                if criterionValue.max ~= nil and mileage > criterionValue.max then
                    customerInterested = false
                    break -- Mileage above maximum
                end
                -- Calculate interest for mileage (lower is better, closer to min which is 0 implicitly)
                if customerInterested then
                    if criterionValue.max ~= nil then
                        interestValue = interestValue + math.max(0, 1 - (mileage / criterionValue.max))
                    else -- No max specified, assume they like low mileage, but no upper bound
                        interestValue = interestValue + 0.5 -- neutral if no max mileage specified
                    end
                end
            elseif criterionName == "numAddedParts" then
                criterionMaxInterest = 1
                local numAddedParts = tonumber(vehicleData.numAddedParts)
                if criterionValue.min ~= nil and numAddedParts < criterionValue.min then
                    customerInterested = false
                    break -- numAddedParts below minimum
                end
                if criterionValue.max ~= nil and numAddedParts > criterionValue.max then
                    customerInterested = false
                    break -- numAddedParts above maximum
                end
                 -- Calculate interest for numAddedParts (higher is better, closer to max)
                if customerInterested then
                    if criterionValue.max ~= nil and criterionValue.min ~= nil then
                        local range = criterionValue.max - criterionValue.min
                        if range > 0 then
                            interestValue = interestValue + (numAddedParts - criterionValue.min) / range
                        elseif numAddedParts >= criterionValue.min and numAddedParts <= criterionValue.max then
                            interestValue = interestValue + 1
                        end
                    elseif criterionValue.max ~= nil then -- only max specified, lower is better
                        interestValue = interestValue + math.max(0, 1 - (numAddedParts / criterionValue.max))
                    elseif criterionValue.min ~= nil then -- only min specified, higher is better
                        interestValue = interestValue + math.min(1, numAddedParts / (criterionValue.min * 3)) -- Cap at 1 when 3x min
                    else
                        interestValue = interestValue + 0.5 -- No min/max, neutral interest
                    end
                end
            elseif criterionName == "numRemovedParts" then
                criterionMaxInterest = 1
                local numRemovedParts = tonumber(vehicleData.numRemovedParts)
                if criterionValue.max ~= nil and numRemovedParts > criterionValue.max then
                    customerInterested = false
                    break -- numRemovedParts above maximum
                end
                -- Calculate interest for numRemovedParts (lower is better, closer to min which is 0 implicitly)
                if customerInterested then
                    if criterionValue.max ~= nil then
                        interestValue = interestValue + math.max(0, 1 - (numRemovedParts / criterionValue.max))
                    else -- No max specified, assume they like low removed parts, but no upper bound
                        interestValue = interestValue + 0.5 -- neutral if no max numRemovedParts specified
                    end
                end
            elseif criterionName == "value" then
                criterionMaxInterest = 1
                local value = tonumber(vehicleData.value)
                if criterionValue.max ~= nil and value > criterionValue.max then
                    customerInterested = false
                    break -- value above maximum
                end
                -- Calculate interest for value (lower is better, closer to min which is 0 implicitly)
                if customerInterested then
                    if criterionValue.max ~= nil then
                        interestValue = interestValue + math.max(0, 1 - (value / criterionValue.max))
                    else -- No max specified, assume they like low value, but no upper bound
                        interestValue = interestValue + 0.5 -- neutral if no max value specified
                    end
                end
            elseif criterionName == "weight" then
                criterionMaxInterest = 1
                local weight = tonumber(vehicleData.weight)
                if criterionValue.max ~= nil and weight > criterionValue.max then
                    customerInterested = false
                    break -- weight above maximum
                end
                -- Calculate interest for weight (lower is better, closer to min which is 0 implicitly)
                if customerInterested then
                    if criterionValue.max ~= nil then
                        interestValue = interestValue + math.max(0, 1 - (weight / criterionValue.max))
                    else -- No max specified, assume they like low weight, but no upper bound
                        interestValue = interestValue + 0.5 -- neutral if no max weight specified
                    end
                end
            elseif criterionName == "powerPerWeight" then
                criterionMaxInterest = 1
                local powerPerWeight = tonumber(vehicleData.powerPerWeight)
                if criterionValue.min ~= nil and powerPerWeight < criterionValue.min then
                    customerInterested = false
                    break -- powerPerWeight below minimum
                end
                -- Calculate interest for powerPerWeight (higher is better, closer to max - assuming no max, so just scale by value)
                if customerInterested then
                    if criterionValue.min ~= nil then -- only min specified, higher is better
                        interestValue = interestValue + math.min(1, powerPerWeight / (criterionValue.min * 3)) -- Cap at 1 when 3x min
                    else
                        interestValue = interestValue + 0.5 -- No min, neutral interest
                    end
                end
            elseif criterionName == "rep" then  -- New Rep Criterion
                criterionMaxInterest = 1
                local rep = tonumber(vehicleData.rep) or 0  -- Default to 0 if nil
                if criterionValue.min ~= nil and rep < criterionValue.min then
                    customerInterested = false
                    break -- Rep below minimum
                end
                -- Calculate interest:  Scale rep to a 0-1 range based on min.  If rep == min, interest is 1.
                if customerInterested then
                    if criterionValue.min ~= nil then
                        interestValue = interestValue + math.min(1, rep / criterionValue.min) -- interest capped at 1
                    else
                        interestValue = interestValue + 0.5 -- Neutral interest if no min specified
                    end
                end
            elseif criterionName == "year" then
                criterionMaxInterest = 1
                local year = tonumber(vehicleData.year) or 0  -- Default to 0 if nil

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
