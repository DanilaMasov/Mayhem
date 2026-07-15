# Mayhem / Confidence Quest - аудит соответствия PRD v3.2 и план исправления

> Исторический аудит от 2026-07-09/10. Часть перечисленных ниже разрывов уже исправлена. Текущий источник архитектурного статуса и дальнейшего плана: `mayhem_architecture_review_v2.md`.

Дата аудита: 2026-07-09; обновлено: 2026-07-10  
Источник истины: `confidence_quest_prd_v3(1).md`  
Текущий проект: локальный web/PWA-прототип без зависимостей

## 1. Короткий вывод

Текущий Mayhem - хороший интерактивный прототип для проверки core-loop на уровне UX-макета и игровых правил. Но он не является production MVP по PRD v3.2.

Главный разрыв: PRD описывает mobile app на Flutter + SQLite + Supabase + StoreKit/Google Play Billing + analytics, а проект реализован как vanilla JS-приложение с `localStorage`, локальными моками sync, PRO, Boss Raid и NPC Training.

Практический статус:

| Блок | Статус | Комментарий |
| --- | --- | --- |
| Приватный RPG-loop без UGC | Ок в прототипе | Нет ленты, лайков, видео и публичных профилей |
| 3 daily-квеста | Ок локально | 2 local обновляются в 12:00 local, общий квест в 00:00 UTC; backend ещё отсутствует |
| Energy / defer / shadow | Ок в прототипе | Safe Defer без штрафа, legacy fail совместим, Shadow и regen покрыты тестами |
| Quest pool | Ок в прототипе | 50 квестов, распределение и удалённые ID валидируются тестами |
| Quest Guide | Частично ок | Есть структурированные гайды и curated overrides, но не 50 полностью отредактированных гайдов |
| NPC Training | Частично ок | Есть node/options-диалоги и подтверждённый XP-бафф, но контент неполный |
| Reflection | Ок в прототипе | Есть поля, история и skip без потери XP |
| Boss Raid | Мок | Нет Supabase, UNIQUE, RPC, real global daily |
| Event log / sync | Частично ок | Локальный append-only контракт валидирует порядок, XP и энергию; server authority отсутствует |
| PRO / billing | Не ок | Debug-only toggle, нет trial/billing/receipt validation |
| Analytics | Не ок | Нет Amplitude и core events |
| Ethical boundaries | Частично ок | Gate показывается после первого квеста; нет production-ссылок на ресурсы по гео |
| Visual UI | Сильный reference UI | Горизонтальная иерархия, общий квест первым, единая система Today/detail/profile/settings; нужен production accessibility pass |

## 2. Что уже сделано хорошо

1. Нет запрещённых v2-social элементов: UGC-видео, Arena, лайки, комментарии, Hall of Fame, leaderboard.
2. Есть три стата: Charisma, Boldness, Networking.
3. Есть энергия с регенерацией `+1% / 10 минут`.
4. Есть Safe Defer: без штрафа, cooldown и потери уже выполненной подготовки.
5. Есть Shadow-квесты с восстановлением энергии и 50% XP.
6. Есть кубик с правильными лимитами: Free 1/day, PRO 3/day + 1 reroll per quest.
7. Есть Boss Raid с Normal / Low-pressure selector и одинаковым XP.
8. Есть reflection-поля: fear, mood, repeat, note.
9. Есть профиль, история, открытие reflection из истории.
10. Базовые unit-тесты проходят через bundled Node.

## 3. Критичные несоответствия

### P0 - Стек и архитектура

PRD требует Flutter, SQLite, Supabase. В проекте:

- `package.json` описывает web prototype на Node server.
- `src/app.js` читает и пишет состояние в `localStorage`.
- `server.mjs` только раздаёт статические файлы.
- Нет Flutter project structure, `pubspec.yaml`, `sqflite`, Supabase client, Edge Functions, migrations.

Риск: дальнейшее развитие web-прототипа не приближает production MVP, если не принято отдельное решение сначала валидировать web-прототип.

Решение:

1. Зафиксировать статус текущего проекта как `prototype`.
2. Создать Flutter app рядом или мигрировать репозиторий в Flutter.
3. Перенести игровые правила из `src/game.js` в Flutter domain layer.
4. Сохранить web-прототип только как reference для UX и тестовых сценариев.

### P0 - Event log и sync

PRD требует append-only event log, SQLite local table, Supabase `quest_events_cloud`, дедупликацию, базовую server validation и incremental cloud stats.

В проекте:

- `state.events` остаётся массивом внутри `localStorage`, а не SQLite source of truth.
- `syncPendingEvents()` реализует детерминированную локальную валидацию и дедупликацию, но не создаёт server authority.
- Canonical event names, client sequence, отдельный `reflection_submitted` и `quest_deferred` уже реализованы.
- Проверяются prior start, канонический XP, Boss/NPC prerequisites и переходы энергии.
- Нет Supabase ingestion, sync every 60 seconds / Wi-Fi / cold start / logout и server-side constraints.

Решение:

1. Перенести существующий canonical enum и валидаторы в production domain/backend.
2. Разделить domain mutations, event creation и transport boundary.
3. В SQLite хранить `quest_events` как append-only source of truth.
4. В Supabase добавить migrations для `quest_events_cloud`, `user_stats_cloud`, `user_auth_link`.
5. Реализовать sync engine с idempotent push и UNIQUE `(user_id, id)`.
6. Добавить серверную проверку `quest_completed` после `quest_started`, XP по пулу, energy clamp.

### P0 - Boss Raid backend отсутствует

В PRD Boss Raid - daily global challenge, обновляется в 00:00 UTC, хранится на сервере, one user = one increment per day.

В проекте:

- Boss quests лежат в `src/data.js`.
- Participant count считается локально через seed/hash.
- Нет `daily_boss_quests`, `boss_quest_participants`, RPC increment.
- Нет anti-abuse pre-logging `quest_started`.
- Нет аналитического event `boss_raid_participated`.

Решение:

1. Создать Supabase schema для boss.
2. Добавить `low_pressure_variant`, `advanced_variant`, `variant` в participant/event metadata.
3. Загружать daily boss с сервера при cold start и daily refresh.
4. При completion делать RPC: insert participant, increment count, return final count.
5. Локально начислять одинаковый XP для normal и low-pressure.

## 4. Product / UX несоответствия

### P1 - Onboarding flow

PRD: первый экран должен быть zero-friction с первым квестом, без регистрации до 3-го выполненного квеста. Medical disclaimer должен появляться на 2-м экране после первого квеста.

В проекте:

- Первый экран - gate "Границы продукта".
- Без принятия disclaimer нельзя начать первый квест.
- Нет регистрации после 3-го квеста.
- Нет прогрессии день 1: спасибо, день 2: уточняющий вопрос, день 3: комплимент вещи, день 4+: полный пул.

Решение:

1. Первый экран: карточка первого квеста + кнопка "Начать".
2. После первого completion: short disclaimer + accept.
3. После третьего completion: registration prompt / auth.
4. Daily generator должен учитывать onboarding day index.

### P1 - Quest pool

Факты текущего пула:

- `QUESTS.length = 50`.
- Shadow = 13, offline = 37.
- Уровни всех квестов: 18 / 20 / 12.
- PRD требует: 18 / 22 / 10.
- Offline stats: charisma 14, boldness 13, networking 10.
- PRD appendix требует: charisma 15, boldness 12, networking 10, shadow 13.
- Переиспользованы ID из списка удалённых v2-квестов: `q_b_001`, `q_b_003`, `q_b_005`, `q_b_006`, `q_b_007`, `q_b_008`, `q_b_012`, `q_c_010`, `q_c_011`, `q_b_011`.

Контент по смыслу выглядит безопасным, но ID reuse опасен для аналитики, миграций и сравнения с v2.

Решение:

1. Принять xlsx/JSON как единственный источник пула.
2. Не переиспользовать удалённые ID.
3. Добавить validator: count, level distribution, stat distribution, shadow count, forbidden fragments.
4. Добавить `safety_reviewed`, `guide_id`, `reward_energy`.

### P1 - Quest Guide

PRD: 50 отдельных guide records, каждый содержит 3 шага, 3-5 фраз, rejection script, low-pressure, advanced.

В проекте:

- `getGuideForQuest()` строит guide из общего шаблона.
- Нет `quest_guides` data source.
- Нет логирования `guide_opened`.
- Нет поведения "после первого выполнения guide сворачивается в иконку".

Решение:

1. Создать `quest_guides.json` или SQLite seed.
2. Написать 50 реальных гайдов.
3. UI: кнопка "Как выполнить?" на карточке, отдельный экран/лист guide.
4. После первого completion данного quest type показывать компактный icon entry.

### P1 - NPC Training

PRD: текстовый диалог-симулятор на базе `npc_dialogs`, options_json, ветки, success ending, +10% XP.

В проекте:

- Кнопка "NPC-тренировка" сразу ставит `npcTrained: true`.
- Нет диалога, веток, options, сценариев.
- Нет расширенных PRO training branches.

Решение:

1. Создать data model `npc_dialogs`.
2. Реализовать диалоговый экран.
3. Для MVP сделать 10 сложных квестов, как допускает PRD.
4. Добавить event `npc_training_completed`.

### P1 - Reflection

PRD: 3 вопроса на одном экране, skip сверху справа, XP всё равно начисляется.

В проекте:

- 3 вопроса есть.
- Опциональная заметка есть.
- Skip отсутствует.
- `reflection_submitted` не логируется отдельно.

Решение:

1. Добавить top-right "Пропустить".
2. Completion должен начислять XP и без reflection.
3. При заполнении отправлять отдельный event `reflection_submitted`.
4. Сохранять `quest_reflections` отдельно от `completed_quests`.

### P1 - PRO

В проекте PRO - локальный toggle.

Нет:

- StoreKit 2.
- Google Play Billing.
- Server-side receipt validation.
- 7-day trial after first completed quest как реальный entitlement.
- Weekly review.
- Adaptive difficulty.
- Additional quest packs.
- Situation prep.

Решение:

1. Сначала оставить только PRO-фичи MVP: dice limit, extended NPC, basic stats.
2. Реальный entitlement получать только от backend после receipt validation.
3. Trial start event привязать к first offline completion.

### P1 - Ethical boundaries

В проекте есть хорошие тексты, но:

- Disclaimer показывается до первого квеста, а PRD требует после первого квеста.
- В settings нет ссылок на профессиональные ресурсы.
- Нет D30+ мягкого предложения.
- Удаление данных очищает только локальный прогресс.

Решение:

1. Перенести disclaimer после первого квеста.
2. Добавить "О приложении" с geo resources.
3. Добавить server-side Data Deletion API.
4. D30+ prompt делать только после production analytics/user day streak.

## 5. Визуальный аудит

Проверено в браузере:

- Mobile viewport: 390 x 844.
- Desktop viewport: 1280 x 720.
- Свежие screenshots сохранены в `artifacts/visual-audit-*.png`.

### Что выглядит хорошо

1. Экран читаемый, карточки аккуратные, текст не вылезает за контейнер.
2. Горизонтального overflow на mobile и desktop не обнаружено.
3. Кнопки имеют нормальную высоту для touch.
4. Boss/Shadow/обычные карточки визуально различимы.
5. Reflection экран прост и быстро заполняется.
6. Bottom nav понятный, основные разделы доступны.

### Что не соответствует PRD или требует правки

1. PRD требует dark mode по умолчанию, а текущий UI светлый, почти editorial/cream.
2. На переходах между экранами сохраняется scroll position. Из-за этого quest/reflection/profile могут открываться не сверху.
3. Toast иногда перекрывает нижнюю часть контента и кнопки около bottom nav.
4. Quest detail длинный: основные action buttons часто ниже fold. Для реального mobile UX лучше sticky action bar или compact guide accordion.
5. На desktop приложение выглядит как phone frame, что нормально для прототипа, но не production Flutter preview.
6. Settings визуально хороший, но слишком текстовый и без реальных resource links.
7. PRO экран визуально приятный, но похож на мок, потому что нет цены, trial copy и store state.

### UI-рекомендации

1. Перевести палитру в тёмную: dark background, restrained neon accents, без агрессивного красного/оранжевого.
2. Добавить `scrollTo(0, 0)` при смене view.
3. Toast поднять выше bottom nav или заменить на inline confirmation.
4. Quest detail: карточка квеста + sticky actions, guide свернуть в accordion.
5. Reflection: добавить skip в top-right.
6. Settings: добавить "О приложении", resources, delete account/data.
7. Boss card: явно показывать Normal / Low-pressure только внутри boss detail перед completion.

## 6. Технический план исправления существующего проекта

### Этап 0 - Зафиксировать статус прототипа

Цель: не путать web prototype и production MVP.

Задачи:

1. Обновить README: "prototype/reference implementation".
2. Добавить документ `mayhem_audit_and_fix_plan.md` в репозиторий.
3. Оставить текущие тесты как regression reference для правил.

Критерий готовности:

- В README ясно написано, что это не Flutter MVP.

### Этап 1 - Быстрые правки web-прототипа

Цель: привести текущий прототип ближе к PRD без большой миграции.

Задачи:

1. Исправить event names: `quest_failed`, `dice_rolled`, `reflection_submitted`.
2. Добавить skip reflection.
3. Исправить onboarding order.
4. Добавить scroll reset при смене view.
5. Исправить toast overlap.
6. Сделать dark theme.
7. Исправить quest pool balance и ID reuse.
8. Добавить validator тесты на распределение и forbidden IDs.

Критерий готовности:

- Unit-тесты проходят.
- Mobile screenshots без visual regressions.
- Прототип product-flow соответствует PRD на уровне UI.

### Этап 2 - Подготовить Flutter migration

Цель: начать production MVP, не теряя уже продуманную domain logic.

Задачи:

1. Создать Flutter app structure.
2. Domain layer:
   - `GameManager`
   - `EnergyService`
   - `QuestRepository`
   - `EventLogRepository`
   - `DailyQuestService`
   - `RewardService`
3. SQLite schema:
   - `user_stats`
   - `quests_pool`
   - `quest_events`
   - `completed_quests`
   - `quest_reflections`
   - `quest_guides`
   - `npc_dialogs`
4. Seed JSON/xlsx importer.
5. Port unit tests from JS to Dart.

Критерий готовности:

- Flutter app запускается локально.
- Offline core loop работает без Supabase.
- SQLite является источником локального состояния.

### Этап 3 - Core loop production

Цель: закрыть W1-W4 PRD.

Задачи:

1. Daily quests at 12:00 local.
2. Onboarding day progression.
3. Energy regen.
4. Safe Defer без списания энергии и cooldown, с событием `quest_deferred`.
5. Shadow quests.
6. Modifier dice limits.
7. Quest Guide from data source.
8. NPC Training for at least 10 hard quests.
9. Reflection with skip.
10. Profile/history.

Критерий готовности:

- Основной loop можно пройти полностью offline.
- Все мутации пишут append-only local events.

### Этап 4 - Supabase backend and sync

Цель: закрыть W5 и W7 PRD.

Задачи:

1. Supabase Auth.
2. Migrations:
   - `daily_boss_quests`
   - `boss_quest_participants`
   - `quest_events_cloud`
   - `user_stats_cloud`
   - `user_auth_link`
3. Edge Functions:
   - sync push
   - receipt validation later
   - delete user data
4. RPC for Boss Raid increment.
5. MVP server validation.
6. Anonymous progress linking after registration.

Критерий готовности:

- Offline events sync idempotently.
- Duplicate event push does not duplicate progress.
- Boss participation increments once per user/day.

### Этап 5 - Analytics and experiments

Цель: закрыть kill/continue criteria.

Задачи:

1. Подключить Amplitude или выбранный analytics SDK.
2. Зарегистрировать все core events из PRD.
3. Настроить funnels:
   - onboarding
   - first quest
   - fail return
   - PRO trial
4. Добавить balance dashboards.

Критерий готовности:

- Можно измерить D7, weekly offline completions, fail return, paywall open/trial.

### Этап 6 - PRO and billing

Цель: monetization MVP.

Задачи:

1. StoreKit 2.
2. Google Play Billing.
3. Server-side receipt validation.
4. Entitlement cache.
5. Trial after first offline completion.
6. PRO feature gates.

Критерий готовности:

- Entitlement нельзя включить локальным toggle.
- Trial and purchase events логируются.

### Этап 7 - QA / release readiness

Задачи:

1. Unit tests: GameManager, Energy, Dice, Rewards, Sync.
2. UI tests: onboarding -> quest -> reflection -> registration.
3. Manual QA: 3 iOS + 2 Android.
4. Performance: cold start <=2s, FPS >=55.
5. App Store / Google Play privacy copy.
6. Data deletion verification.

Критерий готовности:

- TestFlight / Google Play Beta build готов к внешней проверке.

## 7. Приоритет ближайших правок в текущем web-прототипе

Если продолжать чинить именно существующий JS-проект перед Flutter migration, порядок такой:

1. `src/game.js`: canonical event names and separate reflection event.
2. `src/app.js`: onboarding order, reflection skip, scroll reset.
3. `src/styles.css`: dark mode and toast position.
4. `src/data.js`: quest ID cleanup and balance.
5. `tests/game.test.mjs`: добавить проверки event names, onboarding first quest, boss variant metadata, skip reflection, forbidden IDs.
6. `README.md`: честно обозначить prototype scope.

## 8. Definition of Done для соответствия PRD MVP

Проект можно считать соответствующим PRD v3.1 только когда выполнено всё:

1. Flutter app для iOS/Android.
2. SQLite schema из PRD реализована.
3. 50 safety-reviewed quests загружаются из structured source.
4. 50 Quest Guides есть как curated content.
5. Daily local quests выдаются в 12:00 local.
6. Boss Raid приходит с Supabase, has low-pressure variant, increments once per user/day.
7. Event log append-only локально и в cloud.
8. Sync engine имеет MVP validation and dedupe.
9. Reflection можно заполнить или пропустить без потери XP.
10. Registration/Auth появляется после 3-го выполненного квеста.
11. PRO entitlement приходит из billing/backend, не из local toggle.
12. Analytics core events отправляются.
13. Ethical boundaries and data deletion реализованы.
14. Dark mode UI проверен на mobile devices.
15. QA покрывает onboarding -> first quest -> reflection -> registration.
