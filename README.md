# MAYHEM — Social Challenge

## Mobile target

Основная разработка теперь ведётся в `mobile/`: это официальный Flutter-проект с iOS/Android runners, чистым domain layer, SQLite repository и первым рабочим Today/Daily Drop vertical slice. Web-приложение ниже сохраняется как reference prototype и больше не считается production target.

```sh
cd mobile
flutter analyze --no-pub
flutter test --no-pub --no-test-assets -j 1
```

Подробности: `mobile/README.md`.

## Legacy web reference

Корневое web-приложение заморожено как reference implementation для проверки
старых UX и игровых правил. Это не production MVP и не источник архитектуры для
нового Feed. Production target по мастер-ТЗ: Flutter + SQLite + Supabase в
`mobile/`. Web-прототип запускается локально без установки зависимостей и без
сетевых запросов.

План контролируемой feed-first миграции:
`docs/feed-vnext-execution-plan.md`. Первое архитектурное решение:
`docs/adr/0001-feed-first-migration.md`.

## Что реализовано

- дневной core loop: 1 общий `Daily Drop` по UTC + 2 локальных `Backup Runs` с обновлением в 12:00 local;
- жёсткая визуальная система MAYHEM: общий вызов первым, горизонтальные challenge rows, чёрно-белая база, signal red и safety yellow;
- энергия, XP, уровни, три стата: Charisma, Boldness, Networking;
- Safe Defer: квест можно отложить без списания энергии и cooldown; подготовка сохраняется, попытку можно сразу начать снова;
- статус "Затворник" при низкой энергии и Shadow-квесты для восстановления;
- условия попытки: 1 бесплатный бросок в день, PRO-лимиты 3/день + 1 reroll на вызов;
- разбор вызова: отдельное открытие с `guide_opened`, 3 шага, фразы, выход, другой маршрут и усложнение;
- репетиция для средних и главных вызовов: node/options диалог вместо one-click мока, успешное окончание даёт +10% XP;
- Daily Drop без видео-пруфа и давления на посторонних, с двумя равнозначными маршрутами и одинаковым XP;
- Reflection: страх 1-10, состояние 1-10, "хочу повторить", заметка и пропуск без потери XP;
- профиль, история выполнений, повторное открытие reflection;
- локальный append-only event log с canonical event names, client sequence, проверкой порядка событий, наград и переходов энергии, а также дедупликацией для прототипа;
- event sync с хронологической обработкой и индексом prior events вместо квадратичного поиска по журналу;
- заменяемый state repository: versioned envelope, backup предыдущего состояния, восстановление при повреждённом JSON и storage diagnostics;
- runtime-валидация quest catalog и индексированный lookup по ID до запуска UI;
- post-first-quest экран границ продукта: not medical advice, право на отказ, удаление данных;
- локальный paywall-мок для проверки PRO-логики в debug-режиме.

## Запуск

```powershell
npm start
```

Открыть: http://localhost:4173

Обычный режим скрывает внутренние sync/PRO-моки. Для разработки и QA они доступны по адресу `http://localhost:4173/?debug=1`.

## Проверка

```powershell
npm test
```

Тесты покрывают правила энергии, defer-модель и миграцию legacy cooldown, reset-квесты, Daily Drop XP, лимиты условий, canonical event names, skip reflection, разбор / rehearsal events, подготовку без неявного старта, локальную sync-валидацию, catalog validation, backup recovery и нагрузочный sync 10 000 событий.

Для визуальной проверки есть локальный QA-вход:

```text
http://localhost:4173/qa-seed.html
```

Он отмечает onboarding как принятый, включает debug-режим и открывает главный экран. Финальные screenshots лежат в `artifacts/`.

## Что осталось для production

- заменить localStorage на SQLite;
- перенести UI на Flutter;
- подключить Supabase Auth/Storage/Edge Functions;
- добавить StoreKit 2 и Google Play Billing;
- заменить встроенный пул на xlsx/JSON-поставку как единственный источник контента;
- добавить Amplitude и production sync engine.

## Логи и аудит

- `DEVELOPMENT_LOG.md` — журнал решений и проверок текущей разработки.
- `mayhem_audit_and_fix_plan.md` — структурный аудит соответствия PRD и план миграции к production MVP.
- `mayhem_architecture_review_v2.md` — актуальный архитектурный аудит, нагрузочные границы и приоритет следующей разработки.
