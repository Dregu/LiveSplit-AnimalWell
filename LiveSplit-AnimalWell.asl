state("Animal Well") {}

startup {
  refreshRate = 60;

  settings.Add("st", true, "Starting");
  settings.Add("st-new", true, "Start on new game", "st");

  settings.Add("sp", true, "Splitting");
  settings.Add("sp-end", true, "Split on endings", "sp");
  //settings.Add("sp-equipment", true, "Split on equipment", "sp");

  settings.Add("rs", true, "Resetting");
  settings.Add("rs-load", true, "Reset on opening load game menu", "rs");

  settings.Add("tm", true, "Timing");
  settings.Add("tm-force", true, "Force LiveSplit timing method to Game Time", "tm");
  settings.Add("tm-format", false, "Format Game Time as H:M:S:frames (for SRC)", "tm");
  settings.Add("tm-pigt", false, "Use pauseless IGT", "tm");

  vars.ptr = null;
  vars.initDone = false;
  vars.slotDone = false;
  vars.started = false;
}

init {
  vars.state = new MemoryWatcherList();
  vars.slot = new MemoryWatcherList();
  vars.offset = IntPtr.Zero;
  vars.ptr = null;
  vars.initDone = false;
  vars.slotDone = false;
  vars.started = false;
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
        print("[ANIMAL] Pointer: "+vars.offset.ToString("x"));
        vars.state.Add(new MemoryWatcher<byte>(vars.ptr + 0x40c) { Name = "num" });
        vars.state.Add(new MemoryWatcher<byte>(vars.ptr + 0x93644) { Name = "menu" });
        vars.initDone = true;
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
      vars.slot.Add(new MemoryWatcher<int>(vars.ptr + num * 0x27010 + 0x418 + 0x1c0) { Name = "igt" });
      vars.slot.Add(new MemoryWatcher<int>(vars.ptr + num * 0x27010 + 0x418 + 0x1bc) { Name = "pigt" });
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

  if(settings["tm-force"] && timer.CurrentTimingMethod != TimingMethod.GameTime)
    timer.CurrentTimingMethod = TimingMethod.GameTime;

  vars.state.UpdateAll(game);

  if ((vars.state["menu"].Changed && vars.state["menu"].Current == 2) || vars.state["num"].Changed)
    vars.slotDone = false;

  if(!vars.slotDone)
    vars.initSlot();

  if(vars.state["menu"].Changed) print("[ANIMAL] Menu: "+vars.state["menu"].Old.ToString()+" -> "+vars.state["menu"].Current.ToString());

  if (vars.slotDone) {
    vars.slot.UpdateAll(game);
    timer.IsGameTimePaused = (!settings["tm-pigt"] && !vars.slot["igt"].Changed) || !vars.slot["pigt"].Changed;
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

onStart {
  vars.started = true;
}

split {
  if(!vars.slotDone)
    return false;

  if(vars.state["menu"].Current != 0 && vars.state["menu"].Current != 16) return false;

  if(settings["sp-end"] && vars.state["menu"].Changed && vars.state["menu"].Current == 16) {
    print("Split: Ending");
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

onReset {
  vars.started = false;
  vars.slotDone = false;
}

gameTime {
  var gt = vars.slot["igt"].Current;

  if(settings["tm-pigt"])
    gt = vars.slot["pigt"].Current;

  if(settings["tm-format"]) {
    int frames = gt % 60;
    int seconds = gt / 60;
    return TimeSpan.FromSeconds(seconds + frames/100.0);
  } else {
    return TimeSpan.FromSeconds(gt/60.0);
  }
}
