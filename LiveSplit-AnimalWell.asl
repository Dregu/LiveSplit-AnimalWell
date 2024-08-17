state("Animal Well") {}

startup {
  refreshRate = 120;

  settings.Add("st", true, "Starting");
  settings.Add("st-new", true, "Start on 'new game'", "st");

  settings.Add("sp", true, "Splitting");

  settings.Add("sp-end", true, "Split on endings", "sp");
  settings.Add("sp-end-normal", true, "Normal ending / Fireworks", "sp-end");
  settings.Add("sp-end-true", true, "True ending / Ride manticore", "sp-end");
  settings.Add("sp-end-bdtp", true, "BDTP / Eaten by Big Chungus", "sp-end");
  settings.Add("sp-end-popup", false, "Timer popup on fireworks or true ending (alternative)", "sp-end");
  settings.SetToolTip("sp-end-popup", "Getting the accurate IGT requires 'show time' option enabled.\nTrue ending also requires to have picked up the Decorative Bunny fig (4h speedrun).");

  settings.Add("sp-equipment", true, "Split on equipment", "sp");
  settings.Add("sp-equipment-1", true, "Firecracker", "sp-equipment");
  settings.Add("sp-equipment-2", true, "Animal Flute", "sp-equipment");
  settings.Add("sp-equipment-3", true, "Lantern", "sp-equipment");
  settings.Add("sp-equipment-4", true, "Top", "sp-equipment");
  settings.Add("sp-equipment-5", true, "Disc", "sp-equipment");
  settings.Add("sp-equipment-6", true, "B. Wand", "sp-equipment");
  settings.Add("sp-equipment-7", true, "Yoyo", "sp-equipment");
  settings.Add("sp-equipment-8", true, "Slink", "sp-equipment");
  settings.Add("sp-equipment-9", true, "Remote", "sp-equipment");
  settings.Add("sp-equipment-10", true, "Ball", "sp-equipment");
  settings.Add("sp-equipment-11", true, "Wheel", "sp-equipment");
  settings.Add("sp-equipment-12", true, "UV Light", "sp-equipment");

  settings.Add("sp-items", true, "Split on items", "sp");
  settings.Add("sp-items-0", true, "Mock Disc", "sp-items");
  settings.Add("sp-items-1", true, "S. Medal", "sp-items");
  settings.Add("sp-items-2", false, "Cake", "sp-items");
  settings.Add("sp-items-3", true, "House Key", "sp-items");
  settings.Add("sp-items-4", true, "Office Key", "sp-items");
  settings.Add("sp-items-5", false, "Closet Key", "sp-items");
  settings.Add("sp-items-6", true, "E. Medal", "sp-items");
  settings.Add("sp-items-7", true, "F. Pack", "sp-items");

  settings.Add("sp-flames", true, "Split on flames", "sp");
  settings.Add("sp-flames-0", true, "Blue / Seahorse", "sp-flames");
  settings.Add("sp-flames-1", true, "Purple / Dog", "sp-flames");
  settings.Add("sp-flames-2", true, "Violet / Chameleon", "sp-flames");
  settings.Add("sp-flames-3", true, "Green / Ostrich", "sp-flames");

  settings.Add("sp-bunnies", false, "Split on bunnies", "sp");

  settings.Add("rs", true, "Resetting");
  settings.Add("rs-load", true, "Reset on opening 'load game' menu", "rs");
  settings.SetToolTip("rs-load", "Also resets automatically if you start a new game\non a slot that doesn't have a save yet.");

  settings.Add("tm", true, "Timing");
  settings.Add("tm-force", true, "Force LiveSplit timing method to Game Time", "tm");
  settings.Add("tm-popup", false, "Show latest IGT from ending popup on layout (for SRC)", "tm");
  settings.SetToolTip("tm-popup", "Getting the accurate IGT requires 'show time' option enabled.\nTrue ending also requires to have picked up the Decorative Bunny fig (4h speedrun).");
  settings.Add("tm-format", false, "Format Game Time as H:M:S:frames (for SRC, weird)", "tm");
  settings.SetToolTip("tm-format", "Using the term format very loosely here.\nIt just tricks the timer to skip .4s every second,\nwhich might make your deltas seem weird.");
  settings.Add("tm-pigt", false, "Use pauseless IGT (for practice etc)", "tm");

  settings.Add("hc", true, "Hacks");
  settings.SetToolTip("hc", "These options write to the game memory.\nDon't use if you're not sure you can use these.\nI'm just a tool, not the rules.");
  settings.Add("hc-credits-skip", false, "Allow pause menu during credits", "hc");
  settings.SetToolTip("hc-credits-skip", "This writes to the game memory, but technically\nit happens after the run is over, probably.\nUse to GTFO back to the main menu after a run.");

  vars.done = new HashSet<string>();
  vars.state = new MemoryWatcherList();
  vars.slot = new MemoryWatcherList();

  vars.igtText = null;
  vars.popup = (Action)(() => {
    if (vars.initDone)
    {
      if (vars.igtText == null)
      {
        foreach (dynamic component in timer.Layout.Components)
        {
          if (component.GetType().Name == "TextComponent" && component.Settings.Text1 == "Real IGT:")
          {
            vars.igtText = component.Settings;
            break;
          }
        }

        if (vars.igtText == null)
          vars.igtText = vars.CreateTextComponent("Real IGT:");
      }
      if (vars.state["popup"].Current.Contains(":") && vars.igtText != null)
        vars.igtText.Text2 = vars.state["popup"].Current;
    }
  });

  vars.CreateTextComponent = (Func<string, dynamic>)((name) => {
    var textComponentAssembly = Assembly.LoadFrom("Components\\LiveSplit.Text.dll");
    dynamic textComponent = Activator.CreateInstance(textComponentAssembly.GetType("LiveSplit.UI.Components.TextComponent"), timer);
    timer.Layout.LayoutComponents.Add(new LiveSplit.UI.Components.LayoutComponent("LiveSplit.Text.dll", textComponent as LiveSplit.UI.Components.IComponent));
    textComponent.Settings.Text1 = name;
    textComponent.Settings.Text2 = "?";
    return textComponent.Settings;
  });

  vars.ptr = null;
  vars.initDone = false;
  vars.slotDone = false;
  vars.fireworks = 0;
}

init {
  vars.offset = IntPtr.Zero;
  vars.ptr = null;
  vars.initDone = false;
  vars.slotDone = false;
  vars.fireworks = 0;
  vars.pattern = new SigScanTarget(0, "48 8b 05 ?? ?? ?? ?? 48 8b ?? ?? ?? ?? ?? 48 89 8c 1f ec 05 00 00");

  Action initMemory = delegate() {
    vars.state.Clear();
    foreach (var page in game.MemoryPages(true)) {
      var scanner = new SignatureScanner(game, page.BaseAddress, (int) page.RegionSize);
      IntPtr findptr = scanner.Scan(vars.pattern);
      if (findptr != IntPtr.Zero) {
        vars.offset = findptr + game.ReadValue<int>(findptr + 3) + 7;
        var slot_ptr = new DeepPointer(vars.offset);
        vars.ptr = slot_ptr.Deref<IntPtr>(game);
        print("[ANIMAL] Pointer: "+vars.offset.ToString("X")+" = "+vars.ptr.ToString("X"));
        if (vars.ptr != IntPtr.Zero) {
          vars.state.Add(new MemoryWatcher<byte>(vars.ptr + 0x40c) { Name = "num" });
          vars.state.Add(new MemoryWatcher<byte>(vars.ptr + 0x93644) { Name = "menu" });
          vars.state.Add(new MemoryWatcher<byte>(vars.ptr + 0x93608) { Name = "pause" });
          vars.state.Add(new MemoryWatcher<byte>(vars.ptr + 0x754a8 + 0x33608) { Name = "game" });
          vars.state.Add(new MemoryWatcher<byte>(vars.ptr + 0x93670 + 0x5d) { Name = "bean_state" });
          vars.state.Add(new MemoryWatcher<int>(vars.ptr + 0x93670 + 0x20) { Name = "bean_room_x" });
          vars.state.Add(new MemoryWatcher<int>(vars.ptr + 0x93670 + 0x24) { Name = "bean_room_y" });
          vars.state.Add(new StringWatcher(vars.ptr + 0x754d0, 24) { Name = "popup" });
          vars.state.Add(new MemoryWatcher<byte>(modules.First().BaseAddress + 0x2bd5a10 + 0x1b) { Name = "escape" });
          vars.state.Add(new MemoryWatcher<byte>(modules.First().BaseAddress + 0x2bd5b14) { Name = "xinput" });
          vars.state.Add(new MemoryWatcher<byte>(modules.First().BaseAddress + 0x2bd5b58) { Name = "ds" });
          vars.initDone = true;
        }
        break;
      }
    }
    if (vars.offset == IntPtr.Zero) {
      throw new Exception("Could not find magic number for AutoSplitter!");
    }
  };
  vars.init = initMemory;

  Action initSlot = delegate() {
    vars.slot.Clear();

    if (!vars.initDone)
      vars.init();

    if (vars.initDone) {
      var num = vars.state["num"].Current;
      print("[ANIMAL] Slot number: "+num.ToString());
      var offset = num * 0x27010 + 0x418;
      vars.slot.Add(new MemoryWatcher<int>(vars.ptr + offset + 0x1c0) { Name = "igt" });
      vars.slot.Add(new MemoryWatcher<int>(vars.ptr + offset + 0x1bc) { Name = "pigt" });

      vars.slot.Add(new MemoryWatcher<short>(vars.ptr + offset + 0x1dc) { Name = "equipment" });
      vars.slot.Add(new MemoryWatcher<byte>(vars.ptr + offset + 0x1de) { Name = "items" });
      vars.slot.Add(new MemoryWatcher<int>(vars.ptr + offset + 0x21e) { Name = "flames" });
      vars.slot.Add(new MemoryWatcher<int>(vars.ptr + offset + 0x198) { Name = "bunnies" });

      vars.slotDone = true;
    }
  };
  vars.initSlot = initSlot;

  vars.init();
}

update {
  if(!vars.initDone) {
    vars.init();
    return false;
  }

  vars.state.UpdateAll(game);

  if(settings["tm-force"] && timer.CurrentTimingMethod != TimingMethod.GameTime)
    timer.CurrentTimingMethod = TimingMethod.GameTime;

  if (settings["tm-popup"] && vars.igtText == null)
    vars.popup();

  if ((vars.state["menu"].Changed && vars.state["menu"].Current == 2) || vars.state["num"].Changed)
    vars.slotDone = false;

  if(!vars.slotDone)
    vars.initSlot();

  if(vars.state["menu"].Changed) print("[ANIMAL] Menu: "+vars.state["menu"].Old.ToString()+" -> "+vars.state["menu"].Current.ToString()+" (frame "+vars.slot["igt"].Current.ToString()+")");

  if(vars.state["game"].Changed) print("[ANIMAL] Game: "+vars.state["game"].Old.ToString()+" -> "+vars.state["game"].Current.ToString()+" (frame "+vars.slot["igt"].Current.ToString()+")");

  if(vars.state["xinput"].Changed) print("[ANIMAL] XInput: "+vars.state["xinput"].Old.ToString("X")+" -> "+vars.state["xinput"].Current.ToString("X")+" (frame "+vars.slot["igt"].Current.ToString()+")");

  if (vars.state["popup"].Changed) {
    vars.popup();
    print("[ANIMAL] Popup: " + vars.state["popup"].Old.ToString() + " -> " + vars.state["popup"].Current.ToString() + " (frame " + vars.slot["igt"].Current.ToString() + ")");
  }

  if (vars.slotDone) {
    vars.slot.UpdateAll(game);

    if (vars.state["game"].Changed && vars.state["game"].Current == 16)
      vars.fireworks = vars.slot["igt"].Current + 39;

    if (settings["hc-credits-skip"] && vars.state["game"].Current >= 16 && vars.state["menu"].Current == 0 && vars.state["menu"].Old == 0 && vars.state["pause"].Current == 0 &&
        ((vars.state["escape"].Current > 0 && vars.state["escape"].Old == 0) ||
        (vars.state["xinput"].Current == 0x10 && vars.state["xinput"].Old == 0) ||
        (vars.state["ds"].Current == 0x08 && vars.state["ds"].Old == 0))) {
      memory.WriteValue<byte>((IntPtr)(vars.ptr + 0x93608), 1);
      memory.WriteValue<byte>((IntPtr)(vars.ptr + 0x93644), 8);
      //memory.WriteValue<byte>((IntPtr)(vars.ptr + 0x754a8 + 0x33608), 0); // skip credits
    }
  }
}

start {
  if(!vars.slotDone)
    return false;

  if(settings["st-new"] && vars.state["menu"].Current == 0) {
    print("Start: New Game");
    return true;
  }
}

split {
  if(!vars.slotDone)
    return false;

  if (settings["sp-end-normal"] && vars.fireworks > 0 && vars.slot["igt"].Current >= vars.fireworks) {
    print("Split: Fireworks ending");
    vars.fireworks = 0;
    return true;
  } else if (settings["sp-end-true"] && vars.state["bean_state"].Changed && vars.state["bean_state"].Current == 16 && vars.state["bean_room_x"].Current == 7 && vars.state["bean_room_y"].Current == 17) {
    print("Split: True ending");
    return true;
  } else if (settings["sp-end-bdtp"] && vars.state["bean_state"].Changed && vars.state["bean_state"].Current == 13 && vars.state["bean_room_x"].Current == 9 && vars.state["bean_room_y"].Current == 8) {
    print("Split: BDTP");
    return true;
  } else if(settings["sp-equipment"] && vars.slot["equipment"].Changed) {
    for (int i = 1; i <= 12; i++) {
      bool state = (vars.slot["equipment"].Current & (1 << i)) != 0;
      string setting = string.Format("sp-equipment-{0}", i);
      if (state && settings.ContainsKey(setting) && settings[setting] && vars.done.Add(setting)) {
        print("Split: Equipment " + i + " 0x" + (1 << i).ToString("X"));
        return true;
      }
    }
  } else if(settings["sp-items"] && vars.slot["items"].Changed) {
    for (int i = 0; i <= 7; i++) {
      bool state = (vars.slot["items"].Current & (1 << i)) != 0;
      string setting = string.Format("sp-items-{0}", i);
      if (state && settings.ContainsKey(setting) && settings[setting] && vars.done.Add(setting)){
        print("Split: Item " + (i+1) + " 0x" + (1 << i).ToString("X"));
        return true;
      }
    }
  } else if(settings["sp-flames"] && vars.slot["flames"].Changed) {
    for (int i = 0; i <= 3; i++) {
      bool state = (vars.slot["flames"].Current & (4 << i*8)) != 0;
      string setting = string.Format("sp-flames-{0}", i);
      if (state && settings.ContainsKey(setting) && settings[setting] && vars.done.Add(setting)){
        print("Split: Flame " + (i+1));
        return true;
      }
    }
  } else if(settings["sp-bunnies"] && vars.slot["bunnies"].Changed) {
    print("Split: Bunny");
    return true;
  } else if(settings["sp-end-popup"] && vars.state["popup"].Changed && vars.state["popup"].Current.Contains(":")) {
    print("Split: Timer popup");
    return true;
  }
}

reset {
  if (settings["rs-load"] && ((vars.state["menu"].Changed && vars.state["menu"].Current == 2) || vars.state["num"].Changed)) {
    print("Reset: Load Game");
    return true;
  }

  if (vars.slotDone) {
    if (vars.slot["igt"].Changed && vars.slot["igt"].Current < vars.slot["igt"].Old) {
      print("Reset: Restarted same slot");
      return true;
    }
  }
}

onStart {
  vars.done.Clear();
  vars.fireworks = 0;
  vars.slotDone = false;
  if (vars.igtText != null)
    vars.igtText.Text2 = "?";
}

onReset {
  vars.done.Clear();
  vars.fireworks = 0;
  if (vars.igtText != null)
    vars.igtText.Text2 = "?";
}

gameTime {
  var gt = vars.slot["igt"].Current;

  if(settings["tm-pigt"])
    gt = vars.slot["pigt"].Current;

  if(settings["tm-format"]) {
    int frames = gt % 60;
    int seconds = gt / 60;
    return TimeSpan.FromMilliseconds(seconds * 1000 + frames * 10);
  } else {
    return TimeSpan.FromSeconds(gt / 60.0);
  }
}

isLoading {
    return true;
}
