import 'dart:math';

/// 캐릭터 대사 전담 클래스.
///
/// Flutter 위젯에 의존하지 않으므로 단독 테스트 가능.
/// [HomeScreen]에서 인스턴스를 생성한 뒤 아래 메서드로 대사를 뽑는다.
///
/// ```dart
/// final _dialogs = CharacterDialogs();
///
/// // 평상시 탭
/// final comment = _dialogs.randomNormalComment(
///   species: _petSpecies, level: _level ?? 1,
///   topCategory: _topCategory, topCategoryAmount: _topCategoryAmount,
///   prevMonthSpend: _prevMonthSpend, monthlySpend: _monthlySpend,
///   monthlyBudget: _monthlyBudget,
/// );
///
/// // 예산 초과 시 분노
/// final angry = _dialogs.randomAngryComment(
///   species: _petSpecies, level: _level ?? 1,
///   topCategory: _topCategory, topCategoryAmount: _topCategoryAmount,
///   prevMonthSpend: _prevMonthSpend, monthlySpend: _monthlySpend,
///   monthlyBudget: _monthlyBudget,
/// );
///
/// // 놀아주기 버튼
/// final play = _dialogs.playComment(species: _petSpecies);
/// ```
class CharacterDialogs {
  final _rng = Random();

  // ──────────────────────────────────────────────────────────────
  // 공개 API
  // ──────────────────────────────────────────────────────────────

  /// 평상시 탭 대사 — 시간대 + 통계 + 기본 풀을 합산해 랜덤 1개 반환.
  String randomNormalComment({
    required String? species,
    required int level,
    String? topCategory,
    int topCategoryAmount = 0,
    int prevMonthSpend = 0,
    int monthlySpend = 0,
    int monthlyBudget = 0,
  }) {
    final pool = [
      ..._timeComments(species),
      ..._statNormalComments(
        species: species,
        level: level,
        topCategory: topCategory,
        topCategoryAmount: topCategoryAmount,
        prevMonthSpend: prevMonthSpend,
        monthlySpend: monthlySpend,
        monthlyBudget: monthlyBudget,
      ),
      ..._baseComments(species: species, level: level),
    ];
    return pool[_rng.nextInt(pool.length)];
  }

  /// 예산 초과 시 분노 대사 — 통계 기반 + 캐릭터 기본 분노 풀을 합산해 랜덤 1개 반환.
  String randomAngryComment({
    required String? species,
    required int level,
    String? topCategory,
    int topCategoryAmount = 0,
    int prevMonthSpend = 0,
    int monthlySpend = 0,
    int monthlyBudget = 0,
  }) {
    final pool = [
      ..._statAngryComments(
        species: species,
        topCategory: topCategory,
        topCategoryAmount: topCategoryAmount,
        prevMonthSpend: prevMonthSpend,
        monthlySpend: monthlySpend,
        monthlyBudget: monthlyBudget,
      ),
      ..._angryCommentsFor(species: species, level: level),
    ];
    return pool[_rng.nextInt(pool.length)];
  }

  /// 놀아주기 버튼 대사 — 캐릭터별 랜덤 1개 반환.
  String playComment({required String? species}) {
    final pool = _playComments(species);
    return pool[_rng.nextInt(pool.length)];
  }

  // ──────────────────────────────────────────────────────────────
  // 내부 유틸
  // ──────────────────────────────────────────────────────────────

  String _fmt(int amount) => amount
      .toString()
      .replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');

  String _catLabel(String cat) => const {
    'food': '식비',
    'transport': '교통비',
    'shopping': '쇼핑',
    'entertainment': '여가',
    'health': '의료/건강',
    'education': '교육',
    'housing': '주거',
    'communication': '통신',
    'others': '기타',
  }[cat] ??
      cat;

  /// 0 새벽(0~5), 1 아침(6~8), 2 점심(9~13), 3 오후(14~17), 4 저녁(18~20), 5 밤(21~23)
  int _timeSlot() {
    final h = DateTime.now().hour;
    if (h < 6) return 0;
    if (h < 9) return 1;
    if (h < 14) return 2;
    if (h < 18) return 3;
    if (h < 21) return 4;
    return 5;
  }

  // ──────────────────────────────────────────────────────────────
  // 놀아주기
  // ──────────────────────────────────────────────────────────────

  List<String> _playComments(String? species) {
    switch (species) {
      case 'horse':
        return [
          '같이 달리니까 너무 좋다! 히힝~',
          '이렇게 놀아줘서 고마워! 내일도 달리자!',
          '역시 너랑 노는 게 제일 재밌어 히힝!',
          '오늘 같이 뛰어서 기분 최고야!',
        ];
      case 'parrot':
        return [
          '같이 놀자! 놀자! 최고야!',
          '고마워! 고마워! 또 놀러 와!',
          '놀아줘서 행복해! 행복해!',
          '우리 친구야! 친구! 히히!',
        ];
      default: // dolphin
        return [
          '같이 놀아줘서 기분 너무 좋아~',
          '역시 넌 최고야! 또 놀자!',
          '오늘 같이 헤엄친 것 같아서 기뻐!',
          '넌 진짜 좋은 친구야, 알지?',
        ];
    }
  }

  // ──────────────────────────────────────────────────────────────
  // 시간대 멘트
  // ──────────────────────────────────────────────────────────────

  List<String> _timeComments(String? species) {
    final slot = _timeSlot();
    switch (species) {
      case 'horse':
        switch (slot) {
          case 0:
            return [
              '이 시간에 깨어있어? 새벽형 인간이구나 히힝!',
              '나도 못 잔다… 같이 새벽 산책 어때?',
              '새벽엔 지출 없지? 잘 지키고 있어 히힝~',
            ];
          case 1:
            return [
              '좋은 아침이야! 오늘도 절약 달리기 시작~',
              '아침부터 나 보러 와줬어? 기분 좋은데 히힝!',
              '아침 먹었어? 든든하게 먹어야 낭비 안 해!',
              '일찍 일어났네! 오늘 예산 지킬 각오 됐어?',
            ];
          case 2:
            return [
              '점심은 뭐 먹었어? 너무 비싼 거 먹은 건 아니지?',
              '낮에도 나 생각해줬구나~ 고마워 히힝!',
              '점심값 어땠어? 살짝 걱정되는데 히힝…',
              '오늘 오전 지출은 괜찮았어? 오후도 파이팅!',
            ];
          case 3:
            return [
              '오후엔 충동구매 조심해야 해, 알지?',
              '카페 갔다 왔어? 너무 자주 가면 히힝…',
              '오후 슬럼프 올 때 쇼핑하면 안 돼!',
              '퇴근 전 마지막 관문! 지갑 꽉 잡아!',
            ];
          case 4:
            return [
              '저녁이다! 회식 있어? 지갑 잘 지켜~',
              '하루 수고했어! 오늘 지출 어땠어?',
              '저녁은 집밥이 최고야, 히힝!',
              '오늘 하루 절약 잘 했어? 나 좀 자랑스럽지?',
            ];
          default:
            return [
              '이 시간에 폰 보면 안 돼~ 자야지 히힝!',
              '밤에는 온라인 쇼핑 위험해! 나 믿지?',
              '잘 자고 내일 또 절약하자~ 안녕 히힝!',
              '밤 배고프다고 배달 시키면 안 돼 히힝!',
            ];
        }

      case 'parrot':
        switch (slot) {
          case 0:
            return [
              '새벽에 왜 깨있어? 왜 깨있어?',
              '자야 해! 자야 해! 새벽 쇼핑은 금지!',
              '올빼미! 올빼미! 그래도 반가워!',
            ];
          case 1:
            return [
              '좋은 아침! 좋은 아침! 오늘도 절약!',
              '아침부터 왔어? 왔어? 기분 좋아!',
              '밥은 먹었어? 먹었어? 아침은 꼭 먹어!',
              '오늘 계획 세웠어? 세웠어? 절약이 먼저야!',
            ];
          case 2:
            return [
              '점심 뭐 먹었어? 먹었어?',
              '낮에도 절약! 절약! 잘하고 있지?',
              '점심값 얼마야? 얼마야? 설마 비싼 거?',
              '오후도 화이팅! 화이팅!',
            ];
          case 3:
            return [
              '오후 충동구매 조심! 조심!',
              '카페 또 갔어? 또 갔어? 이번 달 몇 번째야!',
              '퇴근하면 바로 집이야! 집!',
              '지갑 닫아! 닫아! 아직 저녁 안 됐어!',
            ];
          case 4:
            return [
              '저녁이야! 저녁! 오늘 어땠어?',
              '회식 가? 가? 너무 많이 마시면 안 돼!',
              '하루 수고했어! 수고했어! 잘 버텼지?',
              '저녁 배달? 배달? 집밥이 훨씬 나아!',
            ];
          default:
            return [
              '자야 해! 자야 해! 밤 쇼핑 위험해!',
              '핸드폰 내려놔! 내려놔! 잘 시간이야!',
              '내일 또 봐! 또 봐! 잘 자~',
              '밤 배달은 안 돼! 안 돼! 절대 안 돼!',
            ];
        }

      default: // dolphin
        switch (slot) {
          case 0:
            return [
              '새벽에 깨어있어? 나도 사실 잠 못 잤어…',
              '이 시간엔 지출 없잖아, 잘하고 있어~',
              '새벽감성 충만하네, 그래도 쇼핑은 참자!',
            ];
          case 1:
            return [
              '아침이다! 오늘 하루도 절약 같이 해보자~',
              '일찍 왔네, 오늘 예산 계획 세웠어?',
              '좋은 아침! 아침밥은 꼭 챙겨 먹어~',
              '오늘도 잘 부탁해! 같이 열심히 하자!',
            ];
          case 2:
            return [
              '점심 잘 먹었어? 너무 비싼 거 시킨 건 아니지?',
              '낮엔 지출 유혹이 많지… 잘 버티고 있지?',
              '점심값 체크해봤어? 오늘 어때?',
              '오후도 같이 힘내자! 넌 할 수 있어~',
            ];
          case 3:
            return [
              '오후에 충동구매 하고 싶은 거 알아, 참아!',
              '퇴근 전이 제일 위험한 시간이야, 조심해~',
              '카페 커피값도 쌓이면 많아지거든?',
              '조금만 더 버티면 저녁이야, 파이팅!',
            ];
          case 4:
            return [
              '오늘 하루 수고했어! 지출은 어땠어?',
              '저녁 약속 있어? 지갑 잘 챙겨~',
              '집밥이 최고야, 믿지? 나처럼 건강하게!',
              '오늘도 잘 해줬어! 진짜 고마워~',
            ];
          default:
            return [
              '이 시간에 폰 보고 있어? 자야 하는데…',
              '밤엔 온라인 쇼핑 손대지 마! 진심으로!',
              '오늘 하루 절약 잘 했어? 푹 쉬어~',
              '밤 배달은 다음에 생각해, 지금은 자자!',
            ];
        }
    }
  }

  // ──────────────────────────────────────────────────────────────
  // 기본 평상시 멘트 (레벨별)
  // ──────────────────────────────────────────────────────────────

  List<String> _baseComments({required String? species, required int level}) {
    switch (species) {
      case 'horse':
        if (level >= 10) {
          return [
            '유니콘이 됐어! 너 덕분이야, 진짜로 히힝!',
            '우린 이제 최강 콤비야~ 절약도 달리기도!',
            '이 정도면 가계부 레전드 아니야? 히힝!',
            '나 요즘 너무 행복해. 같이 있어줘서 고마워!',
            '최고 레벨까지 같이 왔잖아, 우리 진짜 대단하다!',
          ];
        }
        if (level >= 5) {
          return [
            '이제 제법 달릴 줄 알게 됐어~ 히힝!',
            '절약 꽤 늘었지? 나 보는 눈이 있다니까!',
            '조금만 더 하면 유니콘 될 것 같아! 히힝!',
            '요즘 지출 관리 잘하고 있는 거 나 알아~',
            '같이 달리면 뭐든 할 수 있어, 파이팅!',
          ];
        }
        return [
          '안녕! 나 오늘도 여기 있었어~ 히힝!',
          '오늘 뭐 샀어? 필요한 것만 산 거지?',
          '같이 절약 도전 시작해볼까? 히힝~',
          '조랑말이지만 마음만큼은 엄청 크다고!',
          '탭해줘서 좋아! 오늘 하루 어땠어?',
        ];

      case 'parrot':
        if (level >= 10) {
          return [
            '만렙! 만렙! 우리 진짜 해냈어!',
            '가계부 마스터! 마스터! 최고야!',
            '이 정도면 전설이야! 전설!',
            '나 너 자랑스러워! 자랑스러워!',
            '최강 콤비! 콤비! 앞으로도 잘 부탁해!',
          ];
        }
        if (level >= 5) {
          return [
            '잘하고 있어! 잘하고 있어!',
            '절약 실력 늘었어! 늘었어! 나 알아챘어!',
            '조금만 더! 조금만 더! 진화할 수 있어!',
            '오늘도 파이팅! 파이팅!',
            '같이 하면 무서운 거 없어! 없어!',
          ];
        }
        return [
          '안녕! 안녕! 오늘도 왔구나!',
          '뭐 샀어? 뭐 샀어? 필요한 것만?',
          '절약! 절약! 같이 하자!',
          '반가워! 반가워! 보고 싶었어!',
          '오늘 어땠어? 어땠어? 말해줘!',
        ];

      default: // dolphin
        if (level >= 10) {
          return [
            '우리 이제 진짜 레전드 아니야?',
            '최고 레벨까지 왔어. 솔직히 나 감동받았어.',
            '너랑 같이 이 레벨까지 오다니, 진짜 고마워.',
            '이제 지출 관리는 우리 특기잖아~',
            '앞으로도 같이 잘해보자. 나 믿지?',
          ];
        }
        if (level >= 5) {
          return [
            '절약 실력 많이 늘었어. 나 자랑스럽다!',
            '요즘 지출 보니까 꽤 잘 하고 있던데?',
            '조금만 더 하면 진화할 수 있어, 파이팅!',
            '같이 달려온 보람이 있지? 히히~',
            '넌 생각보다 절약을 잘한다니까!',
          ];
        }
        return [
          '탭해줘서 고마워~ 보고 싶었어!',
          '오늘 하루 어땠어? 지출은 괜찮았어?',
          '나랑 같이 절약 여행 시작해볼까?',
          '뭔가 사고 싶을 때 나한테 먼저 물어봐!',
          '같이 있어줘서 좋아, 진짜로~',
        ];
    }
  }

  // ──────────────────────────────────────────────────────────────
  // 통계 기반 평상시 멘트
  // ──────────────────────────────────────────────────────────────

  List<String> _statNormalComments({
    required String? species,
    required int level,
    String? topCategory,
    int topCategoryAmount = 0,
    int prevMonthSpend = 0,
    int monthlySpend = 0,
    int monthlyBudget = 0,
  }) {
    final pool = <String>[];

    // 최다 지출 카테고리
    if (topCategory != null && topCategoryAmount > 0) {
      final cat = _catLabel(topCategory);
      final amt = _fmt(topCategoryAmount);
      switch (species) {
        case 'horse':
          pool.addAll([
            '$cat에 ${amt}원이나 썼어? 나도 좀 놀랐다 히힝!',
            '이번 달 $cat 지출이 제일 많더라. 잘 쓴 거 맞지?',
            '$cat이 이번 달 1위야. 알고 있었어?',
          ]);
          break;
        case 'parrot':
          pool.addAll([
            '$cat! $cat! ${amt}원! 이번 달 1등!',
            '$cat에 제일 많이 썼어! 알고 있어?',
            '이번 달 최다 지출은 $cat! 어때?',
          ]);
          break;
        default:
          pool.addAll([
            '이번 달 $cat에 제일 많이 썼어. ${amt}원이야.',
            '$cat 지출이 1위인 거 알아? 한번 돌아봐~',
            '${amt}원을 $cat에 썼네. 의도한 거야?',
          ]);
      }
    }

    // 전월 대비 절약 / 유사
    if (prevMonthSpend > 0 && monthlySpend > 0) {
      final diff = monthlySpend - prevMonthSpend;
      if (diff < 0) {
        final saved = _fmt(diff.abs());
        switch (species) {
          case 'horse':
            pool.addAll([
              '전달보다 ${saved}원 아꼈어! 대박이지 히힝!',
              '이번 달 절약 성공! 전월보다 ${saved}원 줄었어!',
              '${saved}원 절약이라니, 나 너 진짜 자랑스러워!',
            ]);
            break;
          case 'parrot':
            pool.addAll([
              '절약! 절약! ${saved}원 아꼈어! 최고야!',
              '전달보다 ${saved}원 줄었어! 잘했어! 잘했어!',
              '${saved}원 절약! 절약! 대단해!',
            ]);
            break;
          default:
            pool.addAll([
              '전달보다 ${saved}원 덜 썼어! 진짜 잘했다~',
              '이번 달 알뜰하게 잘 썼네. ${saved}원 절약이야!',
              '${saved}원이나 아꼈어? 나 좀 감동받았어.',
            ]);
        }
      } else if (diff > 0 && diff < (prevMonthSpend * 0.1).toInt()) {
        switch (species) {
          case 'horse':
            pool.addAll([
              '전달이랑 비슷하게 쓰고 있어. 꾸준한 거 좋아 히힝!',
              '안정적이네! 이 페이스 유지하면 진짜 좋아!',
            ]);
            break;
          case 'parrot':
            pool.addAll([
              '전달이랑 비슷! 비슷! 안정적이야!',
              '꾸준해! 꾸준해! 이 페이스 유지해!',
            ]);
            break;
          default:
            pool.addAll([
              '전달이랑 지출이 비슷해. 안정적인 한 달이네~',
              '이 정도면 꾸준하게 잘 하고 있는 거야!',
            ]);
        }
      }
    }

    // 예산 소진율
    if (monthlyBudget > 0 && monthlySpend > 0) {
      final rate = monthlySpend / monthlyBudget;
      if (rate <= 0.5) {
        switch (species) {
          case 'horse':
            pool.addAll([
              '예산 절반도 안 썼어! 이 기세 대박 히힝!',
              '아직 여유 엄청 있어. 잘하고 있다고!',
            ]);
            break;
          case 'parrot':
            pool.addAll([
              '예산 반도 안 썼어! 여유 있어! 여유!',
              '대단해! 대단해! 아직 예산이 많이 남았어!',
            ]);
            break;
          default:
            pool.addAll([
              '예산 절반도 안 썼네. 이달 진짜 여유롭다~',
              '아직 예산이 많이 남았어. 계속 이렇게 해줘!',
            ]);
        }
      } else if (rate >= 0.9 && rate < 1.0) {
        switch (species) {
          case 'horse':
            pool.addAll([
              '예산 거의 다 찼어! 조금만 더 버텨봐 히힝!',
              '이제 막바지야! 마지막 스퍼트 같이 하자!',
            ]);
            break;
          case 'parrot':
            pool.addAll([
              '예산 90%! 90%! 조심해! 조심!',
              '거의 다 왔어! 왔어! 조금만 참아!',
            ]);
            break;
          default:
            pool.addAll([
              '예산 거의 다 썼어. 이번 달 마지막까지 파이팅!',
              '막바지야, 조금만 더 버텨봐. 할 수 있어!',
            ]);
        }
      }
    }

    // 레벨별 응원
    if (level >= 10) {
      switch (species) {
        case 'horse':
          pool.addAll([
            '최고 레벨! 지출도 절약도 우리가 최고야 히힝!',
            '여기까지 온 거 나 진짜 감동받았어~',
          ]);
          break;
        case 'parrot':
          pool.addAll([
            '만렙! 만렙! 가계부 마스터야!',
            '최고야! 최고! 우리 진짜 해냈어!',
          ]);
          break;
        default:
          pool.addAll([
            '최고 레벨까지 왔어. 진짜 대단하다고!',
            '지출 관리 완전히 마스터한 거야. 나 알아~',
          ]);
      }
    } else if (level >= 5) {
      switch (species) {
        case 'horse':
          pool.addAll([
            '꾸준히 절약하면 곧 진화해! 히힝~!',
            '이 페이스면 유니콘 바로 될 것 같아!',
          ]);
          break;
        case 'parrot':
          pool.addAll([
            '중급이야! 중급! 조금만 더 하면 돼!',
            '진화 얼마 안 남았어! 안 남았어!',
          ]);
          break;
        default:
          pool.addAll([
            '중급 레벨이야. 계속 이 페이스로 가보자~',
            '진화가 멀지 않았어. 같이 해내자!',
          ]);
      }
    }

    return pool;
  }

  // ──────────────────────────────────────────────────────────────
  // 기본 분노 멘트 (레벨별)
  // ──────────────────────────────────────────────────────────────

  List<String> _angryCommentsFor({required String? species, required int level}) {
    switch (species) {
      case 'horse':
        if (level >= 10) {
          return const [
            '유니콘도 못 막는 과소비라니… 진짜 답 없다.',
            '예산 초과야. 이번엔 진짜 실망했어.',
            '그 지출, 진짜 꼭 필요했어? 솔직히 말해봐.',
            '나 믿는다면 다음 결제 한 번만 참아봐.',
            '히이잉… 너 때문에 내가 속상하잖아.',
          ];
        }
        if (level >= 5) {
          return const [
            '히이잉! 또 예산 넘겼어? 나 진심으로 화났어!',
            '이러면 같이 못 달려! 잠깐 멈춰봐.',
            '한 번만 더 결제하면 진짜 혼낼거야!',
            '예산 넘긴 거 알지? 어디 가서 도망 못 가~',
            '나 지금 많이 실망했어. 알고 있지?',
          ];
        }
        return const [
          '히힝! 또 샀어?! 같이 절약하기로 했잖아!',
          '조랑말도 이건 못 봐줘… 너무한 거 아니야?',
          '흥! 오늘은 안 놀아줄 거야!',
          '예산 다 썼잖아! 나 삐졌어!',
          '이러면 못 버텨… 제발 참아봐!',
        ];

      case 'parrot':
        if (level >= 10) {
          return const [
            '또 예산 초과야. 학습 능력이 어디 갔어?',
            '내가 몇 번을 말했지? 이번이 진짜 마지막 경고야.',
            '그거 정말 필요했어? 진짜로?',
            '과소비! 과소비! 아직도 몰라?!',
            '나 이제 진짜 화났어! 화났어!',
          ];
        }
        if (level >= 5) {
          return const [
            '예산 초과! 초과! 왜 이러는 거야!',
            '또 그러면 진짜로 화낼 거야!',
            '조금만 참으면 됐을 텐데… 왜!',
            '나 지금 엄청 실망했어! 실망!',
            '멈춰! 멈춰! 더 쓰면 안 돼!',
          ];
        }
        return const [
          '과소비! 과소비! 안 돼! 안 돼!',
          '예산 초과! 흥! 나 삐졌어!',
          '또 샀어?! 으악! 이러면 안 되잖아!',
          '지갑 닫아! 닫아! 제발!',
          '나 울 거야! 진짜로! 그만해!',
        ];

      default: // dolphin
        if (level >= 10) {
          return const [
            '예산 초과야. 다음 결제는 진짜 멈춰.',
            '또 과소비? 나한테도 한계가 있어.',
            '한 번 더 그러면 진짜 가만 안 둔다.',
            '이번엔 솔직히 좀 실망했어. 알지?',
            '그 돈 꼭 썼어야 했어? 다시 생각해봐.',
          ];
        }
        if (level >= 5) {
          return const [
            '벌써 예산 넘겼어? 정신 좀 차리자!',
            '이번 달도 이러면 진짜 곤란한 거 알지?',
            '푸우… 과소비는 이제 그만하자.',
            '나 지금 좀 속상해. 같이 절약하기로 했잖아.',
            '예산 넘긴 거 알지? 내가 지켜보고 있어.',
          ];
        }
        return const [
          '또 과소비야?! 나 삐졌어!',
          '오늘 예산 다 썼잖아… 진짜야?',
          '끼익! 지갑이 우는 소리 들려?',
          '이러면 안 된다고 했잖아! 같이 절약하자!',
          '나 지금 많이 속상해. 다음엔 꼭 참아줘.',
        ];
    }
  }

  // ──────────────────────────────────────────────────────────────
  // 통계 기반 분노 멘트
  // ──────────────────────────────────────────────────────────────

  List<String> _statAngryComments({
    required String? species,
    String? topCategory,
    int topCategoryAmount = 0,
    int prevMonthSpend = 0,
    int monthlySpend = 0,
    int monthlyBudget = 0,
  }) {
    final pool = <String>[];

    // 최다 카테고리 과소비
    if (topCategory != null && topCategoryAmount > 0) {
      final cat = _catLabel(topCategory);
      final amt = _fmt(topCategoryAmount);
      switch (species) {
        case 'horse':
          pool.addAll([
            '$cat에만 ${amt}원?! 히힝, 이건 좀 심하지 않아?',
            '가장 많이 쓴 게 $cat이라니… 한번 줄여봐.',
            '$cat ${amt}원은 솔직히 너무 많아. 다시 생각해봐.',
          ]);
          break;
        case 'parrot':
          pool.addAll([
            '$cat! ${amt}원! 이번 달 최다! 너무 많아!',
            '$cat 과소비! 과소비! 줄여줘!',
            '$cat에 ${amt}원이라니! 진짜야? 진짜야?!',
          ]);
          break;
        default:
          pool.addAll([
            '$cat에 ${amt}원은 좀 많지 않아? 다시 봐봐.',
            '이번 달 $cat 지출이 제일 많아. 이 정도면 과소비야.',
            '${amt}원을 $cat에 썼어? 솔직히 좀 당황했어.',
          ]);
      }
    }

    // 전월 대비 20%↑ 급증
    if (prevMonthSpend > 0 && monthlySpend > prevMonthSpend) {
      final diff = monthlySpend - prevMonthSpend;
      final diffStr = _fmt(diff);
      final rate = (diff / prevMonthSpend * 100).round();
      if (rate >= 20) {
        switch (species) {
          case 'horse':
            pool.addAll([
              '전달보다 ${diffStr}원이나 더 썼어! 히이잉, 왜 이래?!',
              '지출이 전월 대비 $rate%나 늘었어. 나도 당황했다고!',
              '$rate% 증가라니… 히힝, 이건 같이 고민해봐야 해.',
            ]);
            break;
          case 'parrot':
            pool.addAll([
              '전달보다 $rate% 증가! 증가! 심각해!',
              '지출 ${diffStr}원 급증! 급증! 이게 뭔 일이야?!',
              '$rate%나 늘었어! 늘었어! 이러면 안 되잖아!',
            ]);
            break;
          default:
            pool.addAll([
              '전달보다 ${diffStr}원 더 썼어. $rate% 증가야. 좀 조심하자.',
              '지출이 지난달보다 $rate%나 늘었어. 이번 달은 아끼자.',
              '${diffStr}원 급증이야. 솔직히 나 좀 걱정돼.',
            ]);
        }
      }
    }

    // 월 예산 초과
    if (monthlyBudget > 0 && monthlySpend > monthlyBudget) {
      final over = _fmt(monthlySpend - monthlyBudget);
      switch (species) {
        case 'horse':
          pool.addAll([
            '월 예산을 ${over}원이나 초과했어! 이러면 안 되잖아!',
            '예산 ${over}원 넘겼어. 히힝… 나 좀 속상해.',
          ]);
          break;
        case 'parrot':
          pool.addAll([
            '예산 초과 ${over}원! 초과! 지금 당장 멈춰!',
            '${over}원 넘겼어! 넘겼어! 어떡할 거야!',
          ]);
          break;
        default:
          pool.addAll([
            '이번 달 예산 ${over}원 넘겼어. 다음 달은 진짜 계획적으로 가자.',
            '${over}원 초과야. 솔직히 이번 달은 좀 반성해봐.',
          ]);
      }
    }

    return pool;
  }
}
