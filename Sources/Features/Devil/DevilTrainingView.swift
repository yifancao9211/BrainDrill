import SwiftUI

private let devilAccent = BDColor.error

// MARK: - Hub

/// 魔鬼锻炼 hub：红色魔鬼主题，列出限时小游戏（含个人最佳）。
struct DevilTrainingHubView: View {
    @Environment(AppModel.self) private var appModel
    private let accent = devilAccent

    var body: some View {
        let coord = appModel.devilCoord
        Group {
            if coord.calcEngine != nil {
                DevilCalcGameView()
            } else if coord.flipEngine != nil {
                DevilFlipGameView()
            } else if coord.mouseEngine != nil {
                DevilMouseGameView()
            } else if let metrics = coord.lastResult?.devilGameMetrics {
                DevilResultView(metrics: metrics)
            } else {
                hub(coord: coord)
            }
        }
        .padding(.horizontal, 8)
        .padding(.bottom, 8)
    }

    private func hub(coord: DevilCoordinator) -> some View {
        SurfaceCard(
            title: "👹 魔鬼锻炼",
            subtitle: "以限时高压锻炼强化工作记忆。连击越高分数倍率越高，随正确率自适应变难，在能力极限边缘锻炼。",
            accent: accent
        ) {
            VStack(alignment: .leading, spacing: 14) {
                rankBanner(coord: coord)
                streakRow(coord: coord)
                dailyRow(coord: coord)
                ForEach(DevilGameKind.allCases) { game in
                    gameCard(game: game, best: coord.bestScore(for: game), bestN: coord.bestPeakLevel(for: game), stars: coord.stars(for: game))
                }
            }
        }
    }

    private func streakRow(coord: DevilCoordinator) -> some View {
        HStack(spacing: 12) {
            Image(systemName: coord.todayStamped ? "flame.fill" : "flame")
                .font(.system(.title3))
                .foregroundStyle(coord.todayStamped ? BDColor.warm : BDColor.textTertiary)
            VStack(alignment: .leading, spacing: 2) {
                Text("魔鬼连续天数").font(.system(.caption2, design: .rounded)).foregroundStyle(BDColor.textTertiary)
                Text("🔥 \(coord.currentStreak) 天 · 最长 \(coord.bestStreak)")
                    .font(.system(.callout, design: .rounded, weight: .semibold)).foregroundStyle(BDColor.textPrimary)
            }
            Spacer()
            Text(coord.todayStamped ? "今日已修炼" : "今天还没玩")
                .font(.system(.caption, design: .rounded))
                .foregroundStyle(coord.todayStamped ? BDColor.green : BDColor.textSecondary)
        }
        .padding(12)
        .background(BDColor.warm.opacity(0.10), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func rankBanner(coord: DevilCoordinator) -> some View {
        let rank = coord.rank
        let next = rank.next
        let cur = coord.totalPower
        let hi = next?.threshold ?? max(cur, rank.threshold + 1)
        let frac = next == nil ? 1.0 : Double(cur - rank.threshold) / Double(max(1, hi - rank.threshold))
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                Text(rank.symbol).font(.system(size: 30))
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(rank.displayName) · 魔力值 \(cur)")
                        .font(.system(.headline, design: .rounded, weight: .bold))
                        .foregroundStyle(BDColor.textPrimary)
                    Text(next.map { "距「\($0.displayName)」还差 \(max(0, hi - cur))" } ?? "已至巅峰 · 魔王")
                        .font(.system(.caption, design: .rounded)).foregroundStyle(BDColor.textSecondary)
                }
                Spacer()
                VStack(spacing: 1) {
                    Text("成就").font(.system(.caption2, design: .rounded)).foregroundStyle(BDColor.textTertiary)
                    Text("\(coord.unlockedAchievements.count)/\(DevilAchievement.all.count)")
                        .font(.system(.subheadline, design: .rounded, weight: .bold)).foregroundStyle(BDColor.gold)
                }
            }
            ProgressView(value: frac).tint(accent)
        }
        .padding(12)
        .background(accent.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func dailyRow(coord: DevilCoordinator) -> some View {
        HStack(spacing: 12) {
            Image(systemName: coord.dailyDone ? "checkmark.seal.fill" : "target")
                .font(.system(.title3))
                .foregroundStyle(coord.dailyDone ? BDColor.green : accent)
            VStack(alignment: .leading, spacing: 2) {
                Text("每日魔鬼挑战").font(.system(.caption2, design: .rounded)).foregroundStyle(BDColor.textTertiary)
                Text(coord.dailyKind.title).font(.system(.callout, design: .rounded, weight: .semibold)).foregroundStyle(BDColor.textPrimary)
            }
            Spacer()
            Text(coord.dailyKind.progressText(coord.dailyProgress))
                .font(.system(.subheadline, design: .rounded, weight: .bold))
                .foregroundStyle(coord.dailyDone ? BDColor.green : BDColor.textSecondary)
        }
        .padding(12)
        .background(BDColor.panelSecondaryFill, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func gameCard(game: DevilGameKind, best: Int, bestN: Int, stars: Int) -> some View {
        Button {
            appModel.startDevilGame(game)
        } label: {
            HStack(spacing: 14) {
                Image(systemName: game.systemImage)
                    .font(.system(.title2, weight: .semibold))
                    .foregroundStyle(accent)
                    .frame(width: 44, height: 44)
                    .background(accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                VStack(alignment: .leading, spacing: 3) {
                    Text(game.displayName)
                        .font(.system(.headline, weight: .semibold))
                        .foregroundStyle(BDColor.textPrimary)
                    Text(game.subtitle)
                        .font(.system(.caption))
                        .foregroundStyle(BDColor.textSecondary)
                }
                Spacer()
                if best > 0 || stars > 0 || bestN > 0 {
                    VStack(alignment: .trailing, spacing: 2) {
                        if best > 0 {
                            Text("最佳 \(best)").font(.system(.caption, design: .rounded, weight: .semibold)).foregroundStyle(BDColor.gold)
                        }
                        HStack(spacing: 6) {
                            if bestN > 0 {
                                Text("最高 \(game == .calc ? "N=\(bestN)" : "Lv\(bestN)")").font(.system(.caption2, design: .rounded)).foregroundStyle(devilAccent)
                            }
                            if stars > 0 {
                                Text("⭐ \(stars)").font(.system(.caption2, design: .rounded)).foregroundStyle(BDColor.textSecondary)
                            }
                        }
                    }
                }
                Image(systemName: "play.circle.fill")
                    .font(.system(.title2))
                    .foregroundStyle(accent)
            }
            .padding(12)
            .background(BDColor.panelFill, in: RoundedRectangle(cornerRadius: BDMetrics.cornerRadiusMedium, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: BDMetrics.cornerRadiusMedium, style: .continuous)
                    .stroke(Color.bdSeparator.opacity(0.3), lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Shared HUD & juice

private func timeString(_ s: Int) -> String { String(format: "%02d:%02d", s / 60, s % 60) }

private func devilTierColor(_ combo: Int) -> Color {
    switch combo {
    case ..<3:   return BDColor.textSecondary
    case 3..<6:  return BDColor.warm
    case 6..<10: return BDColor.gold
    default:     return BDColor.error
    }
}

private func devilMascot(_ combo: Int) -> String {
    switch combo {
    case ..<3:   return "😈"
    case 3..<6:  return "😣"
    case 6..<10: return "😫"
    default:     return "😱"
    }
}

/// 统一的游戏顶栏：时间(末段红色脉动) · 分数 · 连击层级(含倍率) · 次要指标 · 魔鬼吉祥物 · 进度。
private struct DevilHUD: View {
    let remaining: Int
    let total: Int
    let score: Int
    let combo: Int
    let secondaryLabel: String
    let secondaryValue: String

    var body: some View {
        HStack(spacing: 14) {
            timeStat
            stat("得分", "\(score)", devilAccent)
            comboBadge
            stat(secondaryLabel, secondaryValue, BDColor.textSecondary)
            Text(devilMascot(combo))
                .font(.system(size: 24))
                .scaleEffect(combo >= 3 ? 1.1 : 1)
                .animation(.snappy, value: combo)
            Spacer()
            ProgressView(value: Double(total - remaining), total: Double(max(1, total)))
                .tint(devilAccent).frame(width: 110)
        }
    }

    private var timeStat: some View {
        let urgent = remaining <= 10
        return VStack(spacing: 2) {
            Text(timeString(remaining))
                .font(.system(.headline, design: .rounded, weight: .bold))
                .foregroundStyle(urgent ? BDColor.error : BDColor.textPrimary)
                .scaleEffect(urgent ? (remaining % 2 == 0 ? 1.0 : 1.18) : 1)
                .animation(.easeInOut(duration: 0.25), value: remaining)
            Text("时间").font(.system(.caption2, design: .rounded)).foregroundStyle(BDColor.textSecondary)
        }
    }

    private func stat(_ label: String, _ value: String, _ color: Color) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.system(.headline, design: .rounded, weight: .bold))
                .foregroundStyle(color).contentTransition(.numericText())
            Text(label).font(.system(.caption2, design: .rounded)).foregroundStyle(BDColor.textSecondary)
        }
    }

    private var comboBadge: some View {
        let color = devilTierColor(combo)
        let tier = DevilCombo.tier(combo)
        let mult = DevilCombo.multiplier(combo)
        return VStack(spacing: 2) {
            HStack(spacing: 3) {
                if let tier { Text(tier.symbol).font(.system(size: 13)) }
                Text("×\(combo)")
                    .font(.system(.headline, design: .rounded, weight: .black))
                    .foregroundStyle(color)
                    .contentTransition(.numericText())
            }
            .scaleEffect(combo >= 3 ? 1.0 : 0.95)
            .animation(.snappy, value: combo)
            Text(tier.map { "\($0.name) \(mult)×" } ?? "连击")
                .font(.system(.caption2, design: .rounded, weight: tier == nil ? .regular : .semibold))
                .foregroundStyle(tier == nil ? BDColor.textSecondary : color)
        }
    }
}

/// 答对时上浮淡出的得分提示。通过 `.id(trigger)` 在每次得分时重新挂载触发动画。
private struct FloatingGain: View {
    let gain: Int
    let combo: Int
    @State private var up = false

    var body: some View {
        let mult = DevilCombo.multiplier(combo)
        Text(mult > 1 ? "+\(gain)  ×\(mult)" : "+\(gain)")
            .font(.system(.title3, design: .rounded, weight: .heavy))
            .foregroundStyle(devilTierColor(combo))
            .offset(y: up ? -34 : 6)
            .opacity(up ? 0 : 1)
            .scaleEffect(up ? 1.1 : 0.7)
            .onAppear { withAnimation(.easeOut(duration: 0.8)) { up = true } }
    }
}

// MARK: - 魔鬼计算

struct DevilCalcGameView: View {
    @Environment(AppModel.self) private var appModel
    @State private var remaining: Int = 0
    @State private var missFlash = false
    @State private var warmupScheduler = PhaseScheduler()
    private let ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        Group {
            if let engine = appModel.devilCoord.calcEngine {
                BDTrainingShell(accent: devilAccent) {
                    DevilHUD(remaining: remaining, total: engine.totalSeconds, score: engine.score,
                             combo: engine.combo, secondaryLabel: "深度", secondaryValue: "\(engine.level) 题前")
                } stage: {
                    stage(engine: engine)
                } footer: {
                    Button("退出") { warmupScheduler.cancel(); appModel.devilCoord.cancelSession() }
                        .buttonStyle(BDSecondaryButton(accent: devilAccent))
                        .keyboardShortcut(.cancelAction)
                }
                .overlay(missFlashOverlay)
                .onAppear {
                    remaining = engine.totalSeconds
                    if !engine.isAnswerDue { scheduleWarmup() }
                }
            }
        }
        .onReceive(ticker) { _ in tick() }
        .onDisappear { warmupScheduler.cancel() }
    }

    private var missFlashOverlay: some View {
        RoundedRectangle(cornerRadius: 18)
            .stroke(BDColor.error, lineWidth: 6)
            .opacity(missFlash ? 0.8 : 0)
            .allowsHitTesting(false)
            .animation(.easeOut(duration: 0.4), value: missFlash)
    }

    private func tick() {
        guard let engine = appModel.devilCoord.calcEngine, !engine.isComplete else { return }
        if remaining > 0 { remaining -= 1 }
        else { warmupScheduler.cancel(); appModel.devilCoord.timeUp(); appModel.finalizeDevilGame() }
    }

    /// 开局热身：没有应答题时定时展示新题，直到队列攒满 N+1 出现应答题。
    private func scheduleWarmup() {
        warmupScheduler.schedule(afterMilliseconds: 1100) {
            guard let e = appModel.devilCoord.calcEngine, !e.isComplete else { return }
            withAnimation(.snappy) { e.advanceWarmup() }
            if !e.isAnswerDue { scheduleWarmup() }
        }
    }

    private func stage(engine: DevilCalcEngine) -> some View {
        VStack(spacing: 18) {
            ZStack {
                if engine.lastAnsweredCorrectly == true, engine.correct > 0 {
                    FloatingGain(gain: engine.lastGain, combo: engine.combo).id(engine.correct)
                }
            }
            .frame(height: 24)

            // 当前要记住的算式（最新一题）
            VStack(spacing: 6) {
                Text("记住这道").font(.system(.caption, design: .rounded)).foregroundStyle(.white.opacity(0.85))
                Text("\(engine.current.text) = ?")
                    .font(.system(size: 44, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .contentTransition(.numericText())
            }
            .frame(maxWidth: 460).frame(height: 130)
            .background(
                LinearGradient(colors: [devilAccent, devilAccent.opacity(0.78)], startPoint: .topLeading, endPoint: .bottomTrailing),
                in: RoundedRectangle(cornerRadius: 20, style: .continuous)
            )
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(.white.opacity(0.25), lineWidth: 1))
            .shadow(color: devilAccent.opacity(0.35), radius: 10, y: 4)
            .animation(.spring(response: 0.3, dampingFraction: 0.75), value: engine.current)

            // 应答区：作答 N 题前那道
            if engine.isAnswerDue {
                Text("作答 \(engine.level) 题前那道题的答案")
                    .font(.system(.callout, design: .rounded, weight: .medium))
                    .foregroundStyle(BDColor.textSecondary)
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                    ForEach(Array(engine.options.enumerated()), id: \.offset) { idx, option in
                        Button {
                            withAnimation(.snappy) { engine.answer(option) }
                            if engine.lastAnsweredCorrectly == false { triggerMiss() }
                            if !engine.isAnswerDue { scheduleWarmup() }
                        } label: {
                            Text("\(option)")
                                .font(.system(.title, design: .rounded, weight: .bold))
                                .foregroundStyle(BDColor.textPrimary)
                                .frame(maxWidth: .infinity).frame(height: 66)
                                .background(
                                    LinearGradient(colors: [BDColor.panelFill, BDColor.panelSecondaryFill], startPoint: .top, endPoint: .bottom),
                                    in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                                )
                                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(devilAccent.opacity(0.3), lineWidth: 1.5))
                                .shadow(color: .black.opacity(0.06), radius: 2, y: 1)
                        }
                        .buttonStyle(BDSpringPressStyle())
                        .keyboardShortcut(KeyEquivalent(Character("\(idx + 1)")), modifiers: [])
                    }
                }
                .frame(maxWidth: 460)
            } else {
                Text("先记住屏幕上的算式…")
                    .font(.system(.callout, design: .rounded))
                    .foregroundStyle(BDColor.textTertiary)
                    .frame(height: 66 + 14 + 66)
            }
        }
        .frame(maxWidth: .infinity).padding(.vertical, 8)
    }

    private func triggerMiss() {
        missFlash = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { missFlash = false }
    }
}

// MARK: - 魔鬼翻牌

struct DevilFlipGameView: View {
    @Environment(AppModel.self) private var appModel
    @State private var remaining: Int = 0
    @State private var scheduler = PhaseScheduler()
    @State private var previewScheduler = PhaseScheduler()
    private let ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        Group {
            if let engine = appModel.devilCoord.flipEngine {
                BDTrainingShell(accent: devilAccent) {
                    DevilHUD(remaining: remaining, total: engine.totalSeconds, score: engine.score,
                             combo: engine.combo, secondaryLabel: "档位", secondaryValue: "Lv \(engine.level)")
                } stage: {
                    board(engine: engine)
                } footer: {
                    Button("退出") { scheduler.cancel(); appModel.devilCoord.cancelSession() }
                        .buttonStyle(BDSecondaryButton(accent: devilAccent))
                        .keyboardShortcut(.cancelAction)
                }
            }
        }
        .onAppear {
            remaining = appModel.devilCoord.flipEngine?.totalSeconds ?? 0
            schedulePreviewEnd()
        }
        .onReceive(ticker) { _ in tick() }
        .onChange(of: appModel.devilCoord.flipEngine?.previewing ?? false) { _, preview in
            if preview { schedulePreviewEnd() }
        }
        .onDisappear { scheduler.cancel(); previewScheduler.cancel() }
    }

    private func tick() {
        guard let engine = appModel.devilCoord.flipEngine, !engine.isComplete else { return }
        if remaining > 0 { remaining -= 1 }
        else { scheduler.cancel(); previewScheduler.cancel(); appModel.devilCoord.timeUp(); appModel.finalizeDevilGame() }
    }

    /// 预览期全亮若干秒（随牌数变长）后盖上开始配对。
    private func schedulePreviewEnd() {
        guard let e = appModel.devilCoord.flipEngine, e.previewing else { return }
        let ms = min(800 + e.cards.count * 200, 4200)
        previewScheduler.schedule(afterMilliseconds: ms) {
            withAnimation(.snappy) { appModel.devilCoord.flipEngine?.endPreview() }
        }
    }

    private func board(engine: DevilFlipEngine) -> some View {
        VStack(spacing: 12) {
            ZStack {
                if engine.correct > 0 {
                    FloatingGain(gain: engine.lastGain, combo: engine.combo).id(engine.correct)
                }
            }
            .frame(height: 24)
            Text(engine.previewing ? "记住每张牌的位置！" : "翻开两张找出相同数字")
                .font(.system(.callout, design: .rounded, weight: engine.previewing ? .bold : .regular))
                .foregroundStyle(engine.previewing ? devilAccent : BDColor.textSecondary)
                .animation(.snappy, value: engine.previewing)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: engine.columns), spacing: 12) {
                ForEach(engine.cards) { card in
                    DevilFlipCard(card: card, preview: engine.previewing, accent: devilAccent)
                        .onTapGesture { handleTap(engine: engine, card: card) }
                }
            }
            .frame(maxWidth: 460)
            .animation(.snappy, value: engine.cards)
            .animation(.snappy, value: engine.previewing)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 4)
    }

    private func handleTap(engine: DevilFlipEngine, card: DevilFlipEngine.Card) {
        guard let index = engine.cards.firstIndex(where: { $0.id == card.id }) else { return }
        let resolution = withAnimation(.snappy(duration: 0.28)) { engine.flip(at: index) }
        switch resolution {
        case .mismatch:
            scheduler.schedule(afterMilliseconds: 750) {
                withAnimation(.snappy) { appModel.devilCoord.flipEngine?.resolveMismatch() }
            }
        case .matched:
            if engine.boardCleared {
                scheduler.schedule(afterMilliseconds: 650) {
                    withAnimation(.snappy) { appModel.devilCoord.flipEngine?.dealNext() }
                }
            }
        default:
            break
        }
    }
}

private struct DevilFlipCard: View {
    let card: DevilFlipEngine.Card
    var preview: Bool = false
    let accent: Color

    var body: some View {
        let shown = card.faceUp || card.matched || preview
        ZStack {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(accent.opacity(0.85))
                .overlay(Image(systemName: "flame.fill").foregroundStyle(.white.opacity(0.9)))
                .opacity(shown ? 0 : 1)
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(BDColor.panelFill)
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(accent.opacity(0.35), lineWidth: 1))
                .overlay(
                    Text("\(card.value)")
                        .font(.system(.title, design: .rounded, weight: .bold))
                        .foregroundStyle(card.matched ? BDColor.green : BDColor.textPrimary)
                )
                .opacity(shown ? 1 : 0)
                .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
        }
        .frame(height: 72)
        .rotation3DEffect(.degrees(shown ? 180 : 0), axis: (x: 0, y: 1, z: 0))
        .scaleEffect(card.matched ? 0.9 : 1)
        .opacity(card.matched ? 0.45 : 1)
    }
}

// MARK: - 魔鬼抓鼠

struct DevilMouseGameView: View {
    @Environment(AppModel.self) private var appModel
    @State private var remaining: Int = 0
    @State private var revealed = false
    @State private var scheduler = PhaseScheduler()
    @State private var flipScheduler = PhaseScheduler()
    @State private var submitScheduler = PhaseScheduler()
    private let ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        Group {
            if let engine = appModel.devilCoord.mouseEngine {
                BDTrainingShell(accent: devilAccent) {
                    DevilHUD(remaining: remaining, total: engine.totalSeconds, score: engine.score,
                             combo: engine.combo, secondaryLabel: "目标", secondaryValue: "\(engine.targetCount)")
                } stage: {
                    board(engine: engine)
                } footer: {
                    Button("退出") { scheduler.cancel(); flipScheduler.cancel(); submitScheduler.cancel(); appModel.devilCoord.cancelSession() }
                        .buttonStyle(BDSecondaryButton(accent: devilAccent))
                        .keyboardShortcut(.cancelAction)
                }
                .onChange(of: engine.phase) { _, phase in handlePhase(phase) }
                .onAppear { remaining = engine.totalSeconds; handlePhase(engine.phase) }
            }
        }
        .onReceive(ticker) { _ in tick() }
        .onDisappear { scheduler.cancel(); flipScheduler.cancel(); submitScheduler.cancel() }
    }

    private func tick() {
        guard let engine = appModel.devilCoord.mouseEngine, !engine.isComplete else { return }
        if remaining > 0 { remaining -= 1 }
        else { scheduler.cancel(); flipScheduler.cancel(); submitScheduler.cancel(); appModel.devilCoord.timeUp(); appModel.finalizeDevilGame() }
    }

    /// 记忆(全亮看一眼) → 回忆(凭记忆点) → 揭晓 → 下一回合。
    private func handlePhase(_ phase: DevilMouseEngine.Phase) {
        switch phase {
        case .memorize:
            revealed = false
            flipScheduler.schedule(afterMilliseconds: 320) {
                withAnimation(.spring(response: 0.45, dampingFraction: 0.72)) { revealed = true }
            }
            let mice = appModel.devilCoord.mouseEngine?.targetCount ?? 2
            let view = min(900 + mice * 300, 3000)
            scheduler.schedule(afterMilliseconds: 320 + view) {
                withAnimation(.snappy) { appModel.devilCoord.mouseEngine?.beginRecall() }
            }
        case .reveal:
            submitScheduler.cancel()
            scheduler.schedule(afterMilliseconds: 1300) {
                withAnimation(.snappy) { appModel.devilCoord.mouseEngine?.nextRound() }
            }
        case .recall:
            break
        }
    }

    private func faceUp(_ phase: DevilMouseEngine.Phase) -> Bool {
        switch phase {
        case .recall:   return false
        case .reveal:   return true
        case .memorize: return revealed
        }
    }

    private func board(engine: DevilMouseEngine) -> some View {
        VStack(spacing: 12) {
            ZStack {
                if engine.phase == .reveal, engine.lastRoundCorrect == true, engine.correct > 0 {
                    FloatingGain(gain: engine.lastGain, combo: engine.combo).id(engine.correct)
                } else {
                    Text(prompt(engine.phase))
                        .font(.system(.callout, design: .rounded, weight: .medium))
                        .foregroundStyle(promptColor(engine))
                        .animation(.snappy, value: engine.phase)
                }
            }
            .frame(height: 26)

            let up = faceUp(engine.phase)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: engine.columns), spacing: 12) {
                ForEach(0..<engine.gridCount, id: \.self) { index in
                    DevilMouseCard(
                        faceUp: up,
                        isMouse: engine.targets.contains(index),
                        isSelected: engine.selected.contains(index),
                        phase: engine.phase,
                        accent: devilAccent,
                        index: index
                    )
                    .onTapGesture { withAnimation(.snappy) { engine.toggle(index) } }
                }
            }
            .frame(maxWidth: 420)

            // 选满后短暂停留再自动提交：期间点已选格子可反悔（取消即中止提交）。
            if engine.phase == .recall {
                Text(engine.canSubmit ? "已选满，即将提交…（点已选格子可反悔）" : "已选 \(engine.selected.count)/\(engine.targetCount)")
                    .font(.system(.caption, design: .rounded, weight: .medium))
                    .foregroundStyle(engine.canSubmit ? devilAccent : BDColor.textTertiary)
                    .frame(height: 18)
            }
        }
        .frame(maxWidth: .infinity).padding(.vertical, 4)
        .onChange(of: engine.selected) { _, _ in
            if engine.canSubmit {
                submitScheduler.schedule(afterMilliseconds: 300) {
                    withAnimation(.snappy) { appModel.devilCoord.mouseEngine?.submitSelection() }
                }
            } else {
                submitScheduler.cancel()
            }
        }
    }

    private func prompt(_ phase: DevilMouseEngine.Phase) -> String {
        switch phase {
        case .memorize: "记住老鼠🐭藏在哪些格子（别记成猫🐱）"
        case .recall:   "点出老鼠藏过的格子，别点到猫"
        case .reveal:   "揭晓"
        }
    }

    private func promptColor(_ engine: DevilMouseEngine) -> Color {
        if engine.phase == .reveal { return (engine.lastRoundCorrect ?? false) ? BDColor.green : BDColor.error }
        return BDColor.textSecondary
    }
}

/// 抓鼠卡牌：盖住显示「?」，翻开显示 🐭/🐱；回忆选中高亮，揭晓着色，3D 翻转。
private struct DevilMouseCard: View {
    let faceUp: Bool
    let isMouse: Bool
    let isSelected: Bool
    let phase: DevilMouseEngine.Phase
    let accent: Color
    let index: Int

    var body: some View {
        ZStack {
            back.opacity(faceUp ? 0 : 1)
            front.opacity(faceUp ? 1 : 0)
                .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
        }
        .frame(height: 80)
        .rotation3DEffect(.degrees(faceUp ? 180 : 0), axis: (x: 0, y: 1, z: 0))
        .scaleEffect(isSelected && phase == .recall ? 0.95 : 1)
        .animation(.spring(response: 0.45, dampingFraction: 0.72).delay(Double(index) * 0.02), value: faceUp)
    }

    private var back: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(LinearGradient(
                colors: [accent.opacity(isSelected ? 0.95 : 0.8), accent.opacity(isSelected ? 0.75 : 0.55)],
                startPoint: .topLeading, endPoint: .bottomTrailing))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(.white.opacity(isSelected ? 0.95 : 0.3), lineWidth: isSelected ? 3 : 1))
            .overlay(Text("?").font(.system(size: 28, weight: .heavy, design: .rounded)).foregroundStyle(.white.opacity(0.92)))
            .shadow(color: .black.opacity(0.12), radius: 3, y: 2)
    }

    private var front: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(frontFill)
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(frontStroke, lineWidth: 1.5))
            .overlay(Text(isMouse ? "🐭" : "🐱").font(.system(size: 34)))
            .shadow(color: .black.opacity(0.08), radius: 2, y: 1)
    }

    private var frontFill: Color {
        if phase == .reveal {
            if isMouse { return BDColor.green.opacity(0.22) }
            if isSelected { return BDColor.error.opacity(0.20) }
        }
        return BDColor.panelFill
    }

    private var frontStroke: Color {
        if phase == .reveal {
            if isMouse { return BDColor.green.opacity(0.6) }
            if isSelected { return BDColor.error.opacity(0.6) }
        }
        return Color.bdSeparator.opacity(0.35)
    }
}

// MARK: - 结算（评级 + 个人最佳 + 破纪录）

struct DevilResultView: View {
    @Environment(AppModel.self) private var appModel
    let metrics: DevilGameMetrics
    private let accent = devilAccent

    @State private var stampIn = false

    private var grade: DevilGrade {
        DevilGrade.evaluate(accuracy: metrics.accuracy, peakLevel: metrics.peakLevel, maxLevel: metrics.game.maxLevel, levelWeight: metrics.game.gradeLevelWeight)
    }

    private var gradeColor: Color {
        switch grade {
        case .S: BDColor.gold
        case .A: BDColor.green
        case .B: BDColor.teal
        case .C: BDColor.warm
        case .D: BDColor.textSecondary
        }
    }

    var body: some View {
        let best = appModel.devilCoord.bestScore(for: metrics.game)
        let isRecord = appModel.devilCoord.lastWasRecord

        return BDResultPanel(title: "\(metrics.game.displayName)结算", accent: accent) {
            // 评级印章
            Text(grade.rawValue)
                .font(.system(size: 96, weight: .black, design: .rounded))
                .foregroundStyle(gradeColor)
                .scaleEffect(stampIn ? 1 : 2.2)
                .opacity(stampIn ? 1 : 0)
                .rotationEffect(.degrees(stampIn ? 0 : -18))
                .onAppear { withAnimation(.spring(response: 0.5, dampingFraction: 0.55)) { stampIn = true } }

            Text(grade.remark)
                .font(.system(.callout, design: .rounded, weight: .medium))
                .foregroundStyle(BDColor.textSecondary)

            // 本局星级
            HStack(spacing: 6) {
                ForEach(0..<3, id: \.self) { i in
                    Image(systemName: i < appModel.devilCoord.lastRunStars ? "star.fill" : "star")
                        .font(.system(.title3))
                        .foregroundStyle(i < appModel.devilCoord.lastRunStars ? BDColor.gold : BDColor.textTertiary)
                        .scaleEffect(stampIn ? 1 : 0.3)
                        .animation(.spring(response: 0.4, dampingFraction: 0.5).delay(0.15 + Double(i) * 0.1), value: stampIn)
                }
            }

            if isRecord {
                Text("🏆 新纪录！")
                    .font(.system(.headline, design: .rounded, weight: .bold))
                    .foregroundStyle(BDColor.gold)
                    .padding(.horizontal, 14).padding(.vertical, 6)
                    .background(BDColor.gold.opacity(0.14), in: Capsule())
                    .scaleEffect(stampIn ? 1 : 0.5)
                    .animation(.spring(response: 0.5, dampingFraction: 0.5).delay(0.2), value: stampIn)
            }

            if appModel.devilCoord.lastWasPeakRecord {
                Text(metrics.game == .calc ? "🔥 深度刷新 N=\(metrics.peakLevel)！" : "🔥 档位刷新 Lv\(metrics.peakLevel)！")
                    .font(.system(.headline, design: .rounded, weight: .bold))
                    .foregroundStyle(BDColor.error)
                    .padding(.horizontal, 14).padding(.vertical, 6)
                    .background(BDColor.error.opacity(0.14), in: Capsule())
            }

            if let up = appModel.devilCoord.lastRankUp {
                Text("\(up.symbol) 晋升「\(up.displayName)」！")
                    .font(.system(.headline, design: .rounded, weight: .bold))
                    .foregroundStyle(accent)
                    .padding(.horizontal, 14).padding(.vertical, 6)
                    .background(accent.opacity(0.12), in: Capsule())
            }

            if appModel.devilCoord.todayStamped, appModel.devilCoord.currentStreak > 1 {
                Text("🔥 魔鬼连续 \(appModel.devilCoord.currentStreak) 天")
                    .font(.system(.callout, design: .rounded, weight: .semibold))
                    .foregroundStyle(BDColor.warm)
            }

            if appModel.devilCoord.lastDailyJustCompleted {
                Label("每日魔鬼挑战完成！", systemImage: "checkmark.seal.fill")
                    .font(.system(.callout, design: .rounded, weight: .semibold))
                    .foregroundStyle(BDColor.green)
            }

            if !appModel.devilCoord.lastUnlocked.isEmpty {
                VStack(spacing: 6) {
                    Text("解锁成就").font(.system(.caption, design: .rounded, weight: .semibold)).foregroundStyle(BDColor.textSecondary)
                    ForEach(appModel.devilCoord.lastUnlocked) { ach in
                        HStack(spacing: 8) {
                            Text(ach.symbol).font(.system(.title3))
                            VStack(alignment: .leading, spacing: 1) {
                                Text(ach.title).font(.system(.callout, design: .rounded, weight: .bold)).foregroundStyle(BDColor.textPrimary)
                                Text(ach.detail).font(.system(.caption2, design: .rounded)).foregroundStyle(BDColor.textSecondary)
                            }
                        }
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .background(BDColor.gold.opacity(0.10), in: Capsule())
                    }
                }
            }

            HStack(spacing: 18) {
                VStack(spacing: 2) {
                    Text("\(metrics.score)").font(.system(size: 34, weight: .heavy, design: .rounded)).foregroundStyle(accent)
                    Text("本局得分").font(.system(.caption, design: .rounded)).foregroundStyle(BDColor.textSecondary)
                }
                VStack(spacing: 2) {
                    Text("\(best)").font(.system(size: 22, weight: .bold, design: .rounded)).foregroundStyle(BDColor.gold)
                    Text("个人最佳").font(.system(.caption, design: .rounded)).foregroundStyle(BDColor.textSecondary)
                }
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                BDResultMetricCard(label: "作答", value: "\(metrics.attempted)", color: accent)
                BDResultMetricCard(label: "答对", value: "\(metrics.correct)", color: BDColor.green)
                BDResultMetricCard(label: "正确率", value: "\(Int(metrics.accuracy * 100))%", color: accent)
                BDResultMetricCard(label: "最高连击", value: "×\(metrics.maxCombo)", color: BDColor.gold)
                BDResultMetricCard(
                    label: metrics.game == .calc ? "深度" : "峰值档位",
                    value: metrics.game == .calc ? "N=\(metrics.peakLevel)" : "Lv \(metrics.peakLevel)",
                    color: BDColor.textSecondary
                )
                BDResultMetricCard(label: "时长", value: "\(metrics.durationSeconds)s", color: BDColor.textSecondary)
            }
            .frame(maxWidth: 540)

            HStack(spacing: 12) {
                Button("再来一局") { appModel.startDevilGame(metrics.game) }
                    .buttonStyle(BDPrimaryButton(accent: accent))
                    .keyboardShortcut(.defaultAction)
                Button("返回") { appModel.dismissDevilResult() }
                    .buttonStyle(BDSecondaryButton(accent: accent))
            }
        }
    }
}
