enum ExtinguisherType {
  vp,
  vvk,
  vvp,
  vv;

  String get code {
    switch (this) {
      case ExtinguisherType.vp:
        return 'ВП';
      case ExtinguisherType.vvk:
        return 'ВВК';
      case ExtinguisherType.vvp:
        return 'ВВП';
      case ExtinguisherType.vv:
        return 'ВВ';
    }
  }

  String get fullName {
    switch (this) {
      case ExtinguisherType.vp:
        return 'Вогнегасник порошковий';
      case ExtinguisherType.vvk:
        return 'Вогнегасник вуглекислотний';
      case ExtinguisherType.vvp:
        return 'Вогнегасник водопінний';
      case ExtinguisherType.vv:
        return 'Вогнегасник водний';
    }
  }

  /// Одиниця виміру заряду: ВП/ВВК заряджаються за масою (кг),
  /// ВВП/ВВ — за об'ємом (л).
  String get unit {
    switch (this) {
      case ExtinguisherType.vp:
      case ExtinguisherType.vvk:
        return 'кг';
      case ExtinguisherType.vvp:
      case ExtinguisherType.vv:
        return 'л';
    }
  }

  String get label => '$code — $fullName';

  static ExtinguisherType fromCode(String code) {
    return ExtinguisherType.values.firstWhere(
      (t) => t.code == code,
      orElse: () => ExtinguisherType.vp,
    );
  }
}
