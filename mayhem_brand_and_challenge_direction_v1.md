> **Historical, non-authoritative direction.** Superseded where conflicting by
> `docs/MAYHEM_CURRENT_SPEC_v1.2.md`.

# MAYHEM - brand and challenge direction v1

Дата: 2026-07-11  
Статус: рабочая продуктовая гипотеза для prototype/pilot, не финальный production brand

## 1. Решение в одном абзаце

MAYHEM должен быть не therapy companion и не prank-app. Категория продукта: **social courage sport**. Пользователь получает один главный Daily Drop и два запасных маршрута, принимает вызов, выполняет социально сложное действие и закрывает попытку. Жёсткость направлена на риск отказа, инициативу, ясную речь и присутствие самого игрока. Посторонний человек не становится реквизитом, объектом сексуального контента, обмана или публичного унижения.

## 2. Что показал рынок

### 2.1. Мягкий confidence-сегмент уже занят

Новые приложения `decly`, `Unfear`, `Rejection Therapy` и `Opner` продают очень похожий набор: gentle daily challenges, постепенную экспозицию, AI coach, reflection и спокойный визуал. Это подтверждает спрос, но делает прежний Confidence Quest визуально и вербально взаимозаменяемым с конкурентами.

Источники:

- [decly: daily confidence challenges](https://apps.apple.com/us/app/decly-social-anxiety-coach/id6756065963)
- [Unfear: daily real-world challenges](https://apps.apple.com/us/app/unfear-build-real-confidence/id6759849984)
- [Rejection Therapy: daily comfort-zone challenges](https://apps.apple.com/us/app/rejection-therapy-confidence/id6754168889)
- [Opner: structured daily challenge program](https://apps.apple.com/us/app/opner-social-coach/id6751765292)

### 2.2. Hard challenge продаёт ясный контракт, а не агрессию интерфейса

Официальный 75 Hard имеет 6.4K оценок и рейтинг 4.6 в US App Store. Его сильная сторона: один понятный режим, ежедневный чеклист, история попыток и бескомпромиссная формулировка. При этом сам продукт позже добавил break control, offline mode и исправление дня, то есть даже hard-brand уменьшает операционное наказание, когда оно мешает использованию.

Источник: [75 Hard App Store](https://apps.apple.com/us/app/75-hard/id1502228408)

Вывод: надо заимствовать **ясность обязательства**, а не reset/shame-механику.

### 2.3. У сильных challenge-продуктов есть ритуал и артефакт

- BeReal построил узнаваемый ежедневный ритуал вокруг одного общего момента: [BeReal](https://bereal.com/).
- Nike Run Club разделяет individual, community и custom challenges и выдаёт достижения: [Nike Run Club Challenges](https://www.nike.com/help/a/nrc-challenges).
- Strava показывает challenge progress и складывает завершения в Trophy Case: [Strava Challenges](https://support.strava.com/en-us/articles/15401916-strava-challenges).
- Duolingo делает milestone отдельным визуальным событием и shareable artifact, а не просто числом: [Duolingo streak design](https://blog.duolingo.com/streak-milestone-design-animation/).

Вывод: MAYHEM нужен один Daily Drop, видимый прогресс серии и сильная карточка результата. Бесконечная лента квестов слабее ритуала.

### 2.4. Наказание не является обязательным условием серьёзности

Finch позволяет ставить streak на паузу и восстанавливать его, сохраняя ценность регулярности: [Finch streaks and pause mode](https://help.finchcare.com/hc/en-us/articles/37780736136205-Understanding-Streaks).

Это поддерживает текущий Safe Defer: серьёзность создают выбор, ограниченность Daily Drop и история действий, а не искусственная потеря энергии за отказ.

## 3. Почему сексуальный шок-квест для продавца - плохое решение

Проблема не в самом слове, а в структуре взаимодействия:

1. Продавец находится в captive service role и не выбирает участие в чужом испытании.
2. Sexual/profane prompt превращает личную смелость в дискомфорт третьей стороны.
3. Такой контент трудно рекламировать, показывать в store screenshots и масштабировать на аудиторию младше 18 лет.
4. Он создаёт неправильную оптимизацию контента: следующий квест должен быть ещё более шоковым, а не более полезным.
5. Google Play прямо запрещает приложения, которые содержат/продвигают obscene sexual keywords и facilitate harassment; Apple отклоняет offensive/creepy content и challenges с риском вреда.

Источники:

- [Google Play Inappropriate Content policy](https://support.google.com/googleplay/android-developer/answer/9878810?hl=en)
- [Apple App Review Guidelines 1.1 and 1.4](https://developer.apple.com/app-store/review/guidelines/)

## 4. Новый emotional promise

Не: «мы мягко поможем тебе стать увереннее».

Не: «сделай мерзость ради реакции».

**Обещание:** «Каждый день ты делаешь одну вещь, которую обычно откладываешь из-за социального давления».

Ключевые ощущения:

- до действия: напряжение и ясность;
- во время: личное решение, не случайная провокация;
- после: доказательство самому себе;
- через неделю: видимая серия реальных действий.

## 5. Brand platform

### Working name

**MAYHEM**

Почему подходит:

- уже соответствует project codename;
- короткое, запоминаемое, не звучит как mental-health app;
- позволяет строить язык `Daily Drop`, `Run`, `Closed`, `Nerve`;
- визуально работает без маскота и инфлюенсерской стилизации.

Риск: название требует отдельной trademark/store availability проверки до production.

### Descriptor

`SOCIAL CHALLENGE`

Не использовать на основном пути:

- therapy;
- healing;
- gentle journey;
- become alpha;
- dominate;
- rizz master;
- winner/loser.

### Tone

- коротко;
- конкретно;
- без крика и ложных обещаний;
- без инфоцыганских формул;
- без стыда за defer;
- действие важнее мотивационной цитаты.

## 6. Content contract: hard but not toxic

### Допустимая жёсткость

- риск получить спокойный отказ;
- первым начать разговор;
- ясно высказать мнение;
- попросить о чём-то допустимом;
- войти в открытую групповую ситуацию;
- закончить разговор самому;
- выдержать короткую паузу без нервного оправдания;
- сделать абсурдный conversational constraint с другом или заранее согласившимся участником.

### Запрещённая жёсткость

- sexual/profane prompts для случайных людей;
- действия с captive workers ради реакции;
- унижение, оскорбление, запугивание;
- скрытая запись;
- ложь о болезни, деньгах, угрозе или чрезвычайной ситуации;
- прикосновения и вторжение в пространство;
- принуждение продолжить разговор после отказа;
- challenge, где успех зависит от дискомфорта другого человека.

### Проверка каждого hard challenge

1. Сложно ли это самому игроку?
2. Может ли второй человек спокойно отказаться?
3. Останется ли действие приемлемым, если его повторят 50 раз?
4. Можно ли показать challenge в store screenshot без объяснений?
5. Создаёт ли оно полезный social skill, а не только shock value?

Если хотя бы два ответа отрицательные, challenge удаляется.

## 7. Product loop vNext

1. **Daily Drop:** один главный вызов, общий для всех, обновляется в 00:00 UTC.
2. **Backup Runs:** два персональных вызова другого типа/интенсивности.
3. **Accept:** пользователь явно принимает вызов; старт и timestamp логируются.
4. **Run:** в detail остаются только задача, условия, подготовка и выход.
5. **Close / Defer:** завершить или выйти без наказания.
6. **Debrief:** один быстрый вопрос обязателен, ещё два опциональны.
7. **Artifact:** после завершения создаётся shareable result card без фото посторонних.

## 8. Visual direction

### Palette

- `#080808` - base;
- `#F4F2EC` - primary text;
- `#FF3B30` - signal red, only primary commitment/current state;
- `#FFD400` - timer/reward/shared drop;
- neutral grays for structure.

### Form

- sharp 0-4px corners;
- 1px/2px rules instead of floating cards;
- large numeric challenge IDs;
- uppercase labels with normal letter spacing;
- no gradients, neon glow, glassmorphism, mascots or therapy illustrations;
- motion only when accepting/closing a challenge.

### First viewport

1. MAYHEM wordmark + `SOCIAL CHALLENGE` descriptor.
2. Energy / XP compact telemetry.
3. `DAILY DROP` with countdown.
4. Main challenge, intensity, reward and one primary action.
5. Backup runs begin below the fold.

## 9. Monetization hypothesis

Free:

- Daily Drop;
- 2 Backup Runs;
- basic history;
- safe preparation;
- all safety/defer controls.

PRO candidates:

- themed challenge seasons;
- personal hard-mode programs;
- advanced rehearsal branches;
- weekly performance report;
- custom constraints for consenting friends/groups;
- collectible result-card styles.

Не продавать:

- право на отказ;
- safer route;
- crisis/safety information;
- базовый defer;
- fake participant counts or fake exclusivity.

## 10. Pilot metrics

Главные:

- Daily Drop view -> accept;
- accept -> complete;
- accept -> defer;
- median time to complete;
- D1/D7 return after first completion;
- completions per active user/week;
- report/complaint rate by challenge.

Kill conditions:

- Daily Drop accept <20% после 100 целевых тестеров;
- complaint/report >2% для отдельного challenge;
- D7 completion retention <15%;
- пользователи описывают продукт как prank-app или therapy-app чаще, чем как challenge/sport.

## 11. Что реализуем в prototype сейчас

1. Working brand MAYHEM.
2. Black/white/signal-red visual system.
3. Daily Drop first with countdown and challenge ID.
4. `Принять вызов`, `Закрыть`, `Сойти` вместо мягких формулировок.
5. `Основной / Другой маршрут` вместо `Normal / Low-pressure`.
6. Более интенсивный, но safety-reviewed Boss pool.
7. Никаких UGC, proof-video, leaderboard или сексуальных shock-prompts.
