import 'package:flutter/widgets.dart';

import '../../features/progress/domain/progress_models.dart';

abstract interface class MayhemStrings {
  String get feed;
  String get journey;
  String get you;
  String get begin;
  String get continueLabel;
  String get loading;
  String get retry;
  String get localLoadError;
  String get openingTitle;
  String get openingBody;
  String get calibrationLabel;
  String calibrationProgress(int current, int total);
  String calibrationQuestion(Trait trait);
  List<String> calibrationOptions(Trait trait);
  String get boundariesTitle;
  String get boundariesBody;
  List<String> get boundariesRules;
  String get acceptBoundaries;
  String get initialSignal;
  String get profileRevealBody;
  String traitName(Trait trait);
  String get firstMove;
  String get training;
  String get scenario;
  String get season;
  String get challenge;
  String get offlineReady;
  String get preparation;
  String get guide;
  String get rehearsal;
  String get route;
  String get workingPhrases;
  String get safeExit;
  String get otherRoute;
  String get advancedRoute;
  String get partner;
  String get coach;
  String get rehearsalComplete;
  String get restart;
  String get skipFeedItem;
  String get skipReasonTitle;
  String get skipNotNow;
  String get skipTooIntense;
  String get skipWrongContext;
  String get skipNotRelevant;
  String get feedInteractionFailed;
  String get lowPressureRoute;
  String get primaryRoute;
  String get acceptChallenge;
  String get challengeAccepted;
  String get holdToAcceptHint;
  String get activeChallenge;
  String get activeChallengeBody;
  String get recordResult;
  String get challengeResult;
  String get feltEasier;
  String get feltExpected;
  String get feltHarder;
  String get feltStopped;
  String get optionalReflection;
  String get fearBefore;
  String get feelAfter;
  String get wantRepeat;
  String get privateNoteHint;
  String get saveResult;
  String get challengeActionFailed;
  String get rewardCompleted;
  String get rewardAttempted;
  String feedPosition(int current, int total);
  String get journeyTitle;
  String get journeyInsightEmpty;
  String journeyInsightStrongest(String trait);
  String get traitsTitle;
  String get traitsAccessibleHint;
  String get momentumTitle;
  String get momentumPending;
  String get currentMomentum;
  String get longestMomentum;
  String get shields;
  String nextMilestone(int value);
  String get earnedDays;
  String get historyTitle;
  String get historyEmpty;
  String get attempted;
  String get completed;
  String xpEarned(int value);
  String get privateReflection;
  String get noPrivateReflection;
  String get close;
  String get back;
  String get all;
  String get savedNotes;
  List<String> get weekdaysShort;
  String get qualifyingAction;
  String get noActionForDay;
  String get youTitle;
  String get anonymousLocalProfile;
  String strongestTrait(String trait);
  String get seasonArtifact;
  String get seasonTitle;
  String get seasonUnavailable;
  String get seasonCached;
  String get seasonConfirmed;
  String get seasonRefreshing;
  String get seasonConflict;
  String get seasonPackageIncompatible;
  String get seasonRecoverableError;
  String get seasonNotJoined;
  String get seasonJoining;
  String get seasonJoinFailed;
  String get seasonJoin;
  String get seasonJoinRetry;
  String get seasonJoinExplanation;
  String get seasonJoinRemoteRequired;
  String get seasonExpired;
  String get seasonCompleted;
  String seasonDay(int day);
  String seasonDaysCompleted(int completed, int total);
  String get seasonDayAvailable;
  String get seasonDaySubmitting;
  String get seasonDayFailed;
  String get seasonDayCompleted;
  String seasonCompleteDay(int day);
  String get seasonRetryDay;
  String get seasonActionRemoteRequired;
  String get seasonOpen;
  String get bossLocked;
  String get bossUpcoming;
  String get bossOpen;
  String get bossSubmitting;
  String get bossFailed;
  String get bossAlreadyParticipated;
  String get bossCompleted;
  String get bossChooseRoute;
  String get bossRetry;
  String get bossNormalRoute;
  String get bossLowPressureRoute;
  String get bossAdvancedRoute;
  String seasonParticipants(int count);
  String get settings;
  String get settingsTitle;
  String get account;
  String get notifications;
  String get notificationsUnavailable;
  String get accessibility;
  String get reduceMotion;
  String get reduceMotionBody;
  String get reduceTransparency;
  String get reduceTransparencyBody;
  String get feedback;
  String get haptics;
  String get sound;
  String get ceremonies;
  String get privacy;
  String get privacyBody;
  String get dataAndSync;
  String get localOnlyStatus;
  String get privateNotesStatus;
  String get resetOnDevice;
  String get resetOnDeviceBody;
  String get deleteEverywhere;
  String get deleteEverywhereUnavailable;
  String get deleteEverywhereAvailable;
  String get cloudSessionActive;
  String get remoteSyncFailed;
  String get confirmDeleteEverywhereTitle;
  String get confirmDeleteEverywhereBody;
  String get deleteEverywhereConfirm;
  String get deleteEverywhereFailed;
  String get deleteEverywhereRecoveryRequired;
  String get confirmResetTitle;
  String get confirmResetBody;
  String get cancel;
  String get reset;
  String get resetFailed;
  String get language;
  String get russian;
  String get safetyResources;
  String get safetyResourcesBody;
  String get about;
  String get aboutBody;
  String get diagnostics;
  String get diagnosticsTitle;
  String get featureFlags;
  String get capabilityRevisions;
  String get environment;
  String get enabled;
  String get disabled;
  String get debugOverride;
  String get productionDefault;
  String get localIdentityOnly;
  String get remoteSessionUnavailable;
  String get devicePerformanceOpen;
  String get rankUp;
  String rankUnlocked(String label);
}

class MayhemStringsRu implements MayhemStrings {
  const MayhemStringsRu();

  @override
  String get feed => 'Лента';
  @override
  String get journey => 'Путь';
  @override
  String get you => 'Ты';
  @override
  String get begin => 'НАЧАТЬ';
  @override
  String get continueLabel => 'ПРОДОЛЖИТЬ';
  @override
  String get loading => 'Загружаем локальный прогресс';
  @override
  String get retry => 'ПОВТОРИТЬ';
  @override
  String get localLoadError => 'Не удалось открыть локальные данные.';
  @override
  String get openingTitle => 'РЕАЛЬНАЯ ЖИЗНЬ\nИ ЕСТЬ ИГРА.';
  @override
  String get openingBody =>
      'MAYHEM даёт конкретные социальные вызовы и превращает реальные попытки в прогресс.';
  @override
  String get calibrationLabel => 'НАСТРОЙКА СТАРТОВОЙ СЛОЖНОСТИ';
  @override
  String calibrationProgress(int current, int total) => '$current ИЗ $total';
  @override
  String calibrationQuestion(Trait trait) => switch (trait) {
    Trait.initiation =>
      'Ты пришёл на мероприятие, где почти никого не знаешь. Что ближе?',
    Trait.expression =>
      'В разговоре появляется мнение, с которым ты не согласен. Что сделаешь?',
    Trait.connection =>
      'Знакомый делится важной для него новостью. Как ты обычно отвечаешь?',
    Trait.presence =>
      'В беседе повисла короткая пауза. Какой вариант ощущается естественнее?',
  };
  @override
  List<String> calibrationOptions(Trait trait) => switch (trait) {
    Trait.initiation => const [
      'Подойду к одному человеку.',
      'Сначала осмотрюсь и выберу момент.',
      'Подожду, пока заговорят со мной.',
      'Скорее всего уйду раньше.',
    ],
    Trait.expression => const [
      'Спокойно скажу свою позицию.',
      'Сначала задам уточняющий вопрос.',
      'Поддержу разговор, но мнение оставлю при себе.',
      'Постараюсь сменить тему.',
    ],
    Trait.connection => const [
      'Уточню, что для него в этом важно.',
      'Отмечу конкретную деталь и спрошу дальше.',
      'Поддержу короткой реакцией.',
      'Не сразу пойму, что ответить.',
    ],
    Trait.presence => const [
      'Останусь в паузе и продолжу спокойно.',
      'Дам собеседнику время и посмотрю на реакцию.',
      'Быстро заполню тишину новой темой.',
      'Пауза заставит меня закончить разговор.',
    ],
  };
  @override
  String get boundariesTitle => 'ГРАНИЦЫ ВАЖНЕЕ СЕРИИ';
  @override
  String get boundariesBody =>
      'MAYHEM засчитывает реальную попытку, но никогда не требует продолжать небезопасный или нежеланный контакт.';
  @override
  List<String> get boundariesRules => const [
    'От любого вызова можно отказаться без штрафа.',
    'Чужое «нет» всегда завершает контакт.',
    'Не нужно снимать людей или доказывать выполнение.',
    'Безопасность важнее Momentum.',
    'Попытка уже считается прогрессом.',
  ];
  @override
  String get acceptBoundaries => 'Я ПОНИМАЮ';
  @override
  String get initialSignal => 'СТАРТОВЫЙ СИГНАЛ';
  @override
  String get profileRevealBody =>
      'Это не оценка личности и не диагноз. Карта нужна только для первого подходящего шага.';
  @override
  String traitName(Trait trait) => switch (trait) {
    Trait.initiation => 'Инициатива',
    Trait.expression => 'Самовыражение',
    Trait.connection => 'Контакт',
    Trait.presence => 'Присутствие',
  };
  @override
  String get firstMove => 'ПЕРВЫЙ ШАГ';
  @override
  String get training => 'ТРЕНИРОВКА';
  @override
  String get scenario => 'СЦЕНАРИЙ';
  @override
  String get season => 'SEASON';
  @override
  String get challenge => 'ВЫЗОВ';
  @override
  String get offlineReady => 'Доступно без сети';
  @override
  String get preparation => 'ПОДГОТОВКА';
  @override
  String get guide => 'РАЗБОР';
  @override
  String get rehearsal => 'РЕПЕТИЦИЯ';
  @override
  String get route => 'МАРШРУТ';
  @override
  String get workingPhrases => 'РАБОЧИЕ ФРАЗЫ';
  @override
  String get safeExit => 'ЧИСТЫЙ ВЫХОД';
  @override
  String get otherRoute => 'ДРУГОЙ МАРШРУТ';
  @override
  String get advancedRoute => 'УСЛОЖНЕНИЕ';
  @override
  String get partner => 'СОБЕСЕДНИК';
  @override
  String get coach => 'COACH';
  @override
  String get rehearsalComplete => 'РЕПЕТИЦИЯ ПРОЙДЕНА';
  @override
  String get restart => 'НАЧАТЬ СНАЧАЛА';
  @override
  String get skipFeedItem => 'Пропустить';
  @override
  String get skipReasonTitle => 'ПОЧЕМУ ПРОПУСКАЕШЬ?';
  @override
  String get skipNotNow => 'Не сейчас';
  @override
  String get skipTooIntense => 'Слишком интенсивно';
  @override
  String get skipWrongContext => 'Не тот контекст';
  @override
  String get skipNotRelevant => 'Неактуально';
  @override
  String get feedInteractionFailed =>
      'Не удалось сохранить действие. Попробуй ещё раз.';
  @override
  String get lowPressureRoute => 'МЯГКИЙ МАРШРУТ';
  @override
  String get primaryRoute => 'ОСНОВНОЙ';
  @override
  String get acceptChallenge => 'ПРИНЯТЬ ВЫЗОВ';
  @override
  String get challengeAccepted => 'ВЫЗОВ ПРИНЯТ';
  @override
  String get holdToAcceptHint => 'Двойное нажатие подтверждает без удержания';
  @override
  String get activeChallenge => 'АКТИВНЫЙ ВЫЗОВ';
  @override
  String get activeChallengeBody => 'Принятый вызов сохранён на устройстве.';
  @override
  String get recordResult => 'ЗАПИСАТЬ РЕЗУЛЬТАТ';
  @override
  String get challengeResult => 'РЕЗУЛЬТАТ ВЫЗОВА';
  @override
  String get feltEasier => 'Легче';
  @override
  String get feltExpected => 'Как ожидал';
  @override
  String get feltHarder => 'Сложнее';
  @override
  String get feltStopped => 'Остановился';
  @override
  String get optionalReflection => 'РЕФЛЕКСИЯ';
  @override
  String get fearBefore => 'Напряжение до';
  @override
  String get feelAfter => 'Состояние после';
  @override
  String get wantRepeat => 'Готов повторить';
  @override
  String get privateNoteHint => 'Приватная заметка на устройстве';
  @override
  String get saveResult => 'ЗАСЧИТАТЬ';
  @override
  String get challengeActionFailed =>
      'Не удалось сохранить действие. Локальные данные не изменены.';
  @override
  String get rewardCompleted => 'ВЫЗОВ ЗАВЕРШЁН';
  @override
  String get rewardAttempted => 'ПОПЫТКА ЗАСЧИТАНА';
  @override
  String feedPosition(int current, int total) => '$current из $total';
  @override
  String get journeyTitle => 'ТВОЙ ПУТЬ';
  @override
  String get journeyInsightEmpty =>
      'Первое реальное действие начнёт менять эту карту.';
  @override
  String journeyInsightStrongest(String trait) =>
      '$trait сейчас движется увереннее остальных.';
  @override
  String get traitsTitle => 'КАРТА НАВЫКОВ';
  @override
  String get traitsAccessibleHint =>
      'Нажми на карту, чтобы открыть точные значения.';
  @override
  String get momentumTitle => 'MOMENTUM';
  @override
  String get momentumPending => 'День ожидает проверки часового пояса';
  @override
  String get currentMomentum => 'Текущая серия';
  @override
  String get longestMomentum => 'Лучшая серия';
  @override
  String get shields => 'Защита';
  @override
  String nextMilestone(int value) => 'Следующая отметка: $value';
  @override
  String get earnedDays => 'ЗАСЧИТАННЫЕ ДНИ';
  @override
  String get historyTitle => 'ИСТОРИЯ ДЕЙСТВИЙ';
  @override
  String get historyEmpty => 'Попытки и завершения появятся здесь.';
  @override
  String get attempted => 'Попытка';
  @override
  String get completed => 'Завершено';
  @override
  String xpEarned(int value) => '+$value XP';
  @override
  String get privateReflection => 'Приватная заметка';
  @override
  String get noPrivateReflection => 'Приватной заметки нет.';
  @override
  String get close => 'ЗАКРЫТЬ';
  @override
  String get back => 'Назад';
  @override
  String get all => 'Все';
  @override
  String get savedNotes => 'С заметками';
  @override
  List<String> get weekdaysShort => const [
    'ПН',
    'ВТ',
    'СР',
    'ЧТ',
    'ПТ',
    'СБ',
    'ВС',
  ];
  @override
  String get qualifyingAction => 'ЗАСЧИТАННОЕ ДЕЙСТВИЕ';
  @override
  String get noActionForDay => 'В этот день действие не засчитано.';
  @override
  String get youTitle => 'ТВОЁ ПРИСУТСТВИЕ';
  @override
  String get anonymousLocalProfile => 'Анонимный локальный профиль';
  @override
  String strongestTrait(String trait) => 'Сильнейший сигнал: $trait';
  @override
  String get seasonArtifact => 'Артефакт Season откроется после реального шага';
  @override
  String get seasonTitle => 'ТЕКУЩИЙ SEASON';
  @override
  String get seasonUnavailable => 'Активный Season сейчас недоступен.';
  @override
  String get seasonCached => 'Показана последняя сохранённая версия';
  @override
  String get seasonConfirmed => 'Состояние подтверждено сервером';
  @override
  String get seasonRefreshing => 'Обновляем состояние с сервера';
  @override
  String get seasonConflict => 'Состояние изменилось. Требуется обновление';
  @override
  String get seasonPackageIncompatible =>
      'Этот Season несовместим с текущей версией приложения.';
  @override
  String get seasonRecoverableError =>
      'Не удалось загрузить Season. Повтори попытку.';
  @override
  String get seasonNotJoined => 'Участие ещё не подтверждено';
  @override
  String get seasonJoining => 'Подтверждаем участие';
  @override
  String get seasonJoinFailed => 'Участие не подтверждено. Можно повторить';
  @override
  String get seasonJoin => 'ВСТУПИТЬ В SEASON';
  @override
  String get seasonJoinRetry => 'ПОВТОРИТЬ ПОДТВЕРЖДЕНИЕ';
  @override
  String get seasonJoinExplanation =>
      'Участие начнётся только после подтверждения сервера. Повторный запрос не создаст дубликат.';
  @override
  String get seasonJoinRemoteRequired =>
      'Для вступления нужна настроенная облачная сессия и сеть.';
  @override
  String get seasonExpired => 'Season завершён';
  @override
  String get seasonCompleted => 'Season пройден';
  @override
  String seasonDay(int day) => 'ДЕНЬ $day ИЗ 7';
  @override
  String seasonDaysCompleted(int completed, int total) =>
      '$completed из $total дней завершено';
  @override
  String get seasonDayAvailable => 'Дневной вызов доступен';
  @override
  String get seasonDaySubmitting => 'Подтверждаем завершение дня';
  @override
  String get seasonDayFailed => 'Завершение дня не подтверждено';
  @override
  String get seasonDayCompleted => 'Дневной вызов подтверждён';
  @override
  String seasonCompleteDay(int day) => 'ЗАВЕРШИТЬ ДЕНЬ $day';
  @override
  String get seasonRetryDay => 'ПОВТОРИТЬ ЗАВЕРШЕНИЕ';
  @override
  String get seasonActionRemoteRequired =>
      'Для подтверждения действия нужна облачная сессия и сеть.';
  @override
  String get seasonOpen => 'ОТКРЫТЬ SEASON';
  @override
  String get bossLocked => 'Boss закрыт';
  @override
  String get bossUpcoming => 'Boss скоро откроется';
  @override
  String get bossOpen => 'Boss открыт';
  @override
  String get bossSubmitting => 'Подтверждаем участие в Boss';
  @override
  String get bossFailed => 'Участие в Boss не подтверждено';
  @override
  String get bossAlreadyParticipated => 'Участие в Boss уже принято';
  @override
  String get bossCompleted => 'Boss завершён';
  @override
  String get bossChooseRoute => 'ВЫБРАТЬ МАРШРУТ BOSS';
  @override
  String get bossRetry => 'ПОВТОРИТЬ ОТПРАВКУ BOSS';
  @override
  String get bossNormalRoute => 'Прямой маршрут';
  @override
  String get bossLowPressureRoute => 'Сниженная интенсивность';
  @override
  String get bossAdvancedRoute => 'Продвинутый маршрут';
  @override
  String seasonParticipants(int count) => '$count подтверждённых участников';
  @override
  String get settings => 'Настройки';
  @override
  String get settingsTitle => 'НАСТРОЙКИ';
  @override
  String get account => 'АККАУНТ';
  @override
  String get notifications => 'Уведомления';
  @override
  String get notificationsUnavailable =>
      'Выключены до отдельного запроса разрешения и production gate.';
  @override
  String get accessibility => 'ДОСТУПНОСТЬ';
  @override
  String get reduceMotion => 'Уменьшить движение';
  @override
  String get reduceMotionBody => 'Заменяет переходы мгновенными состояниями.';
  @override
  String get reduceTransparency => 'Уменьшить прозрачность';
  @override
  String get reduceTransparencyBody => 'Использует непрозрачные поверхности.';
  @override
  String get feedback => 'ОТКЛИК';
  @override
  String get haptics => 'Тактильный отклик';
  @override
  String get sound => 'Звук';
  @override
  String get ceremonies => 'Сцены награды';
  @override
  String get privacy => 'ПРИВАТНОСТЬ';
  @override
  String get privacyBody =>
      'Приватные заметки остаются на этом устройстве и не попадают в события, аналитику или логи.';
  @override
  String get dataAndSync => 'ДАННЫЕ И СИНХРОНИЗАЦИЯ';
  @override
  String get localOnlyStatus =>
      'Сейчас прогресс хранится локально. Облачная сессия не создана.';
  @override
  String get privateNotesStatus =>
      'Текст приватных заметок не синхронизируется.';
  @override
  String get resetOnDevice => 'СБРОСИТЬ ДАННЫЕ НА ЭТОМ УСТРОЙСТВЕ';
  @override
  String get resetOnDeviceBody =>
      'Удалит локальный прогресс, историю, кэш и приватные заметки. Облачные данные это действие не удаляет.';
  @override
  String get deleteEverywhere => 'УДАЛИТЬ АККАУНТ И ДАННЫЕ ВЕЗДЕ';
  @override
  String get deleteEverywhereUnavailable =>
      'Недоступно без сети и подтверждённой облачной сессии.';
  @override
  String get deleteEverywhereAvailable =>
      'Удалит облачный аккаунт и все локальные данные после подтверждения сервера.';
  @override
  String get cloudSessionActive =>
      'Защищённая анонимная сессия активна. Прогресс синхронизируется после завершённых действий.';
  @override
  String get remoteSyncFailed =>
      'Синхронизация не удалась. Локальные данные сохранены.';
  @override
  String get confirmDeleteEverywhereTitle => 'Удалить аккаунт и данные везде?';
  @override
  String get confirmDeleteEverywhereBody =>
      'Серверные и локальные данные будут удалены без возможности восстановления. При ошибке ничего локально не удалится.';
  @override
  String get deleteEverywhereConfirm => 'УДАЛИТЬ ВЕЗДЕ';
  @override
  String get deleteEverywhereFailed =>
      'Сервер не подтвердил удаление. Данные и сессия сохранены.';
  @override
  String get deleteEverywhereRecoveryRequired =>
      'Облачное удаление подтверждено. Локальная очистка не завершена; повторите действие.';
  @override
  String get confirmResetTitle => 'Сбросить данные на устройстве?';
  @override
  String get confirmResetBody =>
      'Локальный прогресс, история и приватные заметки будут удалены без возможности восстановления.';
  @override
  String get cancel => 'ОТМЕНА';
  @override
  String get reset => 'СБРОСИТЬ';
  @override
  String get resetFailed => 'Не удалось сбросить локальные данные.';
  @override
  String get language => 'ЯЗЫК';
  @override
  String get russian => 'Русский';
  @override
  String get safetyResources => 'БЕЗОПАСНОСТЬ';
  @override
  String get safetyResourcesBody =>
      'Не продолжай контакт после отказа. В небезопасной ситуации обращайся к подходящей экстренной или профессиональной помощи.';
  @override
  String get about => 'О ПРИЛОЖЕНИИ';
  @override
  String get aboutBody =>
      'MAYHEM — приватная практика реальных социальных действий. Это не терапия и не медицинский продукт.';
  @override
  String get diagnostics => 'Диагностика';
  @override
  String get diagnosticsTitle => 'ДИАГНОСТИКА';
  @override
  String get featureFlags => 'FEATURE FLAGS';
  @override
  String get capabilityRevisions => 'РЕВИЗИИ ПОЛИТИК';
  @override
  String get environment => 'СРЕДА';
  @override
  String get enabled => 'включено';
  @override
  String get disabled => 'выключено';
  @override
  String get debugOverride => 'debug override';
  @override
  String get productionDefault => 'production default';
  @override
  String get localIdentityOnly => 'Только локальная identity';
  @override
  String get remoteSessionUnavailable => 'Облачная сессия отсутствует';
  @override
  String get devicePerformanceOpen => 'Physical-device performance gate открыт';
  @override
  String get rankUp => 'НОВЫЙ РАНГ';
  @override
  String rankUnlocked(String label) => 'Открыт $label';
}

class MayhemStringsScope extends InheritedWidget {
  const MayhemStringsScope({
    super.key,
    required this.strings,
    required super.child,
  });

  final MayhemStrings strings;

  static MayhemStrings of(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<MayhemStringsScope>()
          ?.strings ??
      const MayhemStringsRu();

  @override
  bool updateShouldNotify(MayhemStringsScope oldWidget) =>
      oldWidget.strings != strings;
}

extension MayhemStringsContext on BuildContext {
  MayhemStrings get strings => MayhemStringsScope.of(this);
}
