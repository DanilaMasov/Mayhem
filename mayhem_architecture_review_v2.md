> **Historical, non-authoritative audit.** Use
> `docs/MAYHEM_CURRENT_SPEC_v1.2.md` and `docs/CURRENT_STATUS.md`.

# MAYHEM — архитектурный и продуктовый аудит v2

Дата: 2026-07-11  
Источник требований: `confidence_quest_prd_v3(1).md`  
Статус кода: reference web prototype, не production MVP

## 1. Объективный вывод

Текущий проект хорошо проверяет правила игры и пользовательский поток, но пока не является масштабируемым мобильным продуктом в смысле PRD.

Сильные стороны:

- доменные операции в `src/game.js` в основном чистые и детерминированные;
- append-only event contract, client sequence, дедупликация и базовая валидация уже моделируются;
- игровые правила покрыты регрессионными тестами;
- UI не содержит backend-логики Supabase или биллинга;
- контент имеет стабильные ID, уровни и типы статов.

Ограничения:

- это vanilla JS + `localStorage`, а PRD требует Flutter + SQLite + Supabase;
- `src/app.js`, `src/game.js` и `src/data.js` остаются крупными модулями;
- текущий sync является локальным валидатором, а не сетевым sync engine;
- `stats`, `reflections` и `completedQuestIdsByDate` хранятся рядом с event log и могут рассинхронизироваться при будущем merge нескольких устройств;
- нет настоящих auth, server authority, billing, analytics и data deletion backend;
- нагрузка браузерного `localStorage` не эквивалентна нагрузке SQLite/PostgreSQL.

Итоговая оценка:

| Контур | Оценка | Комментарий |
| --- | ---: | --- |
| Domain rules | 8/10 | Детерминированы и хорошо тестируются |
| Content integrity | 8/10 | Добавлена runtime-валидация каталога |
| Local recovery | 7/10 | Есть versioned envelope и backup, но не транзакционная БД |
| UI modularity | 5/10 | Рендер-функции разделены логически, но находятся в одном файле |
| Event sync model | 6/10 | Контракт хороший, transport/server authority отсутствуют |
| Production scalability | 3/10 | Нельзя честно оценивать без Supabase и реального workload |
| Product validation | 4/10 | Курс менялся без пилота и данных пользователей |

## 2. Самое важное идейное решение

Сейчас главный риск не технический, а продуктовый. Production target зафиксирован как Flutter mobile, но полная Supabase/billing-реализация до проверки core loop может закрепить неверный формат продукта дорогой инфраструктурой.

Лучший путь:

1. Продолжать разработку в Flutter mobile; web-версию оставить только как reference поведения.
2. Заморозить визуальный язык на время первого Android/iOS pilot.
3. Проверять одну гипотезу: возвращаются ли люди ради следующего Daily Drop и выполняют ли реальные действия.
4. До тяжёлой backend/billing-фазы собрать минимум: completion rate, defer rate, повтор после defer, `want_repeat`, жалобы на конкретные задания.
5. Выпускать mobile vertical slices, а не переносить одновременно все web-экраны и всю Supabase-инфраструктуру.

Flutter/SQLite vertical slice начат в `mobile/`. Дальше нужно расширять переносимые domain contracts, тесты, контентную схему и recovery; backend развивать только там, где это помогает мобильному пилоту.

## 3. Соответствие PRD

### Совпадает

- приватный core loop без UGC, публичной ленты и proof-видео;
- энергия, regen, Safe Defer, Shadow quests;
- три стата и XP;
- подготовка, modifier, guide, reflection;
- Daily Drop обновляется по UTC;
- append-only события и базовые server-like проверки;
- право выйти из попытки без наказания.

### Осознанно изменено

- бренд и тон MAYHEM жёстче спокойного `Confidence Quest` из PRD;
- главный Daily Drop визуально и продуктово важнее двух локальных квестов;
- после первого completion Backup Runs выбираются из уровней 2–3;
- модификаторы больше не требуют абсурдного поведения с посторонними;
- варианты называются «основной / другой маршрут», хотя event contract сохраняет `normal / low_pressure` для совместимости.

### Всё ещё не соответствует

- нет Flutter, SQLite, Supabase, Edge Functions и migrations;
- нет настоящего server-side recalculation и multi-device merge;
- нет anonymous-to-auth linking;
- нет StoreKit / Google Play Billing и receipt validation;
- нет production analytics и kill/continue dashboard;
- нет server-side data deletion;
- onboarding из PRD заменён более сложным первым вызовом, что повышает риск раннего оттока.

## 4. Архитектура после текущего этапа

```text
src/app.js
  UI rendering + interaction orchestration
        |
        +-- src/application/maintenance-loop.js
        |     clock/scheduler + energy refresh + sync + persistence orchestration
        |
        +-- src/domain/quest-catalog.js
        |     validation + indexed content lookup
        |
        +-- src/game.js
        |     domain facade: quest lifecycle, energy, rewards, event contract
        |
        +-- src/infrastructure/state-repository.js
              load/save/clear port implementation for localStorage
              versioned envelope + backup + recovery diagnostics
```

Эта форма уже позволяет заменить `state-repository.js` на SQLite-adapter, не меняя UI-контракт. Scheduler также вынесен из UI; следующий инфраструктурный шаг — отдельный сетевой sync transport с batched ack/retry.

## 5. Нагрузочная оценка

До этапа 2E поиск предшествующего `quest_started` или `npc_training_completed` проходил по всему принятому журналу для каждого события. При N событиях worst case был близок к O(N²).

После этапа 2E:

- события один раз сортируются по `createdAt`, `clientSequence`, `id`;
- последние принятые события индексируются по `questId + eventType`;
- полный sync работает за O(N log N) из-за сортировки;
- перевёрнутый журнал из 10 000 событий проходит локальную валидацию примерно за десятки миллисекунд на текущей машине.

Что этот тест не доказывает:

- пропускную способность Supabase;
- contention при одновременных записях;
- latency мобильной сети;
- стоимость full rebuild PostgreSQL;
- ограничения памяти слабого Android-устройства.

Для backend нужны отдельные k6/pgbench-сценарии после появления реального ingestion endpoint.

## 6. Прочность и восстановление

Реализовано:

- чтение старого raw JSON без ручной миграции;
- новый versioned storage envelope;
- backup предыдущего валидного состояния;
- fallback `primary -> backup -> default`;
- storage errors не роняют активную сессию;
- diagnostics не логируют пользовательские reflection-данные;
- reset удаляет primary и backup.

Остаётся:

- SQLite transactions;
- checksum или database integrity check;
- event-derived cache rebuild;
- conflict policy для двух устройств;
- encrypted storage для чувствительных заметок;
- экспорт/удаление server-side данных.

## 7. Следующая архитектура production

```text
Flutter Presentation
        |
Application Controllers / Use Cases
        |
Pure Domain
  QuestLifecycle | Energy | Rewards | Event Contracts | Catalog Validation
        |
Ports
  StateRepository | EventRepository | SyncTransport | CatalogSource | Analytics
        |
Adapters
  SQLite | Supabase RPC/Edge Functions | Remote Config | Amplitude
```

Правила зависимостей:

1. Domain ничего не знает о Flutter, SQLite, Supabase и времени устройства.
2. Время и UUID передаются зависимостями.
3. UI вызывает use cases, а не пишет state напрямую.
4. Event log — источник правды; stats/reflections/history — перестраиваемые read models.
5. Sync transport идемпотентен и работает батчами с cursor/ack.
6. Любой remote catalog проходит ту же валидацию, что встроенный seed.

## 8. Приоритет дальнейшей разработки

### P0 — до расширения фич

1. Разделить `src/game.js` на event log, quest lifecycle, energy/rewards и selectors, сохранив façade для обратной совместимости.
2. Разделить interaction orchestration в `app.js` на use cases и view modules.
3. Перевести content source из JS-модуля в versioned JSON с schema validation.
4. Добавить rebuild read models из event log и тест на расхождение кэша.
5. Добавить анонимный installation ID в события.

### P1 — после пилота core loop

1. Flutter shell и SQLite schema.
2. Supabase migrations + idempotent batch ingestion.
3. Cold-start pull, push pending, ack cursor, retry/backoff.
4. Anonymous-to-auth linking после третьего completion.
5. Analytics adapter и kill/continue dashboard.

### P2 — только после подтверждения retention

1. Billing и server entitlement.
2. Weekly review и adaptive difficulty.
3. Расширение NPC-контента.
4. Post-MVP anti-abuse.

## 9. Критерий готовности следующего этапа

Архитектурный этап считается завершённым, когда:

- UI не импортирует browser storage напрямую;
- content payload валидируется до использования;
- 10k локальных событий обрабатываются без квадратичной деградации;
- повреждённое primary state восстанавливается из backup;
- все игровые регрессии проходят;
- documentation честно отделяет prototype guarantees от production guarantees.

Эти критерии выполнены в Stage 2E. Следующая разработка должна начинаться со split `game.js`, read-model rebuild и use-case слоя, а не с новых визуальных компонентов.
