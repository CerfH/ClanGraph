/// 预置的 Demo 家族数据，首次启动时自动加载。
///
/// 包含三代中国家庭：祖辈、父母辈（含兄弟姐妹）、本辈，
/// 以及真实的礼金记录。
class DemoData {
  static const String json = '''
{
  "members": [
    {
      "id": "root",
      "name": "我",
      "relationship": "本人",
      "gender": "男",
      "bio": "",
      "parents": ["father", "mother"],
      "children": [],
      "spouseId": null,
      "giftHistory": [
        {"id": "g1", "amount": 2000, "event": "结婚", "date": "2025-10-01T00:00:00.000"},
        {"id": "g2", "amount": 500, "event": "生日", "date": "2026-03-15T00:00:00.000"}
      ]
    },
    {
      "id": "father",
      "name": "黄建国",
      "relationship": "爸爸",
      "gender": "男",
      "bio": "",
      "parents": ["p_grandpa", "p_grandma"],
      "children": ["root", "sister"],
      "spouseId": "mother",
      "giftHistory": [
        {"id": "g3", "amount": 1000, "event": "生日", "date": "2025-08-20T00:00:00.000"}
      ]
    },
    {
      "id": "mother",
      "name": "李秀英",
      "relationship": "妈妈",
      "gender": "女",
      "bio": "",
      "parents": ["m_grandpa", "m_grandma"],
      "children": ["root", "sister"],
      "spouseId": "father",
      "giftHistory": [
        {"id": "g4", "amount": 800, "event": "生日", "date": "2025-12-05T00:00:00.000"}
      ]
    },
    {
      "id": "sister",
      "name": "黄小雅",
      "relationship": "妹妹",
      "gender": "女",
      "bio": "在读大学",
      "parents": ["father", "mother"],
      "children": [],
      "spouseId": null,
      "giftHistory": []
    },
    {
      "id": "p_grandpa",
      "name": "黄德厚",
      "relationship": "爷爷",
      "gender": "男",
      "bio": "",
      "parents": [],
      "children": ["father", "uncle", "aunt_p"],
      "spouseId": "p_grandma",
      "giftHistory": [
        {"id": "g5", "amount": 2000, "event": "春节", "date": "2026-01-29T00:00:00.000"}
      ]
    },
    {
      "id": "p_grandma",
      "name": "陈桂花",
      "relationship": "奶奶",
      "gender": "女",
      "bio": "",
      "parents": [],
      "children": ["father", "uncle", "aunt_p"],
      "spouseId": "p_grandpa",
      "giftHistory": []
    },
    {
      "id": "uncle",
      "name": "黄建军",
      "relationship": "叔叔",
      "gender": "男",
      "bio": "父亲的弟弟",
      "parents": ["p_grandpa", "p_grandma"],
      "children": ["cousin_tang"],
      "spouseId": null,
      "giftHistory": [
        {"id": "g6", "amount": 3000, "event": "结婚", "date": "2024-05-20T00:00:00.000"}
      ]
    },
    {
      "id": "aunt_p",
      "name": "黄美玲",
      "relationship": "姑姑",
      "gender": "女",
      "bio": "父亲的姐姐",
      "parents": ["p_grandpa", "p_grandma"],
      "children": ["cousin_biao"],
      "spouseId": null,
      "giftHistory": []
    },
    {
      "id": "cousin_tang",
      "name": "黄小明",
      "relationship": "堂弟",
      "gender": "男",
      "bio": "叔叔的儿子",
      "parents": ["uncle"],
      "children": [],
      "spouseId": null,
      "giftHistory": []
    },
    {
      "id": "cousin_biao",
      "name": "张丽丽",
      "relationship": "表妹",
      "gender": "女",
      "bio": "姑姑的女儿",
      "parents": ["aunt_p"],
      "children": [],
      "spouseId": null,
      "giftHistory": []
    },
    {
      "id": "m_grandpa",
      "name": "李大山",
      "relationship": "外公",
      "gender": "男",
      "bio": "",
      "parents": [],
      "children": ["mother", "uncle_m", "aunt_m"],
      "spouseId": "m_grandma",
      "giftHistory": [
        {"id": "g7", "amount": 1500, "event": "春节", "date": "2026-01-29T00:00:00.000"}
      ]
    },
    {
      "id": "m_grandma",
      "name": "王秀兰",
      "relationship": "外婆",
      "gender": "女",
      "bio": "",
      "parents": [],
      "children": ["mother", "uncle_m", "aunt_m"],
      "spouseId": "m_grandpa",
      "giftHistory": []
    },
    {
      "id": "uncle_m",
      "name": "李国强",
      "relationship": "舅舅",
      "gender": "男",
      "bio": "母亲的弟弟",
      "parents": ["m_grandpa", "m_grandma"],
      "children": [],
      "spouseId": null,
      "giftHistory": [
        {"id": "g8", "amount": 1000, "event": "乔迁", "date": "2025-11-08T00:00:00.000"}
      ]
    },
    {
      "id": "aunt_m",
      "name": "李秀兰",
      "relationship": "姨妈",
      "gender": "女",
      "bio": "母亲的姐姐",
      "parents": ["m_grandpa", "m_grandma"],
      "children": ["cousin_m_biao"],
      "spouseId": null,
      "giftHistory": []
    },
    {
      "id": "cousin_m_biao",
      "name": "赵小刚",
      "relationship": "表弟",
      "gender": "男",
      "bio": "姨妈的儿子",
      "parents": ["aunt_m"],
      "children": [],
      "spouseId": null,
      "giftHistory": []
    }
  ]
}
''';
}
