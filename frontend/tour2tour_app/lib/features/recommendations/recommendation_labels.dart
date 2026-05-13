String recommendationTagLabel(String raw) {
  final key = raw.trim().toLowerCase();
  const labels = <String, String>{
    'place': 'Место',
    'food': 'Еда',
    'stay': 'Проживание',
    'shopping': 'Покупки',
    'activity': 'Активность',
    'attraction': 'Достопримечательность',
    'landmark': 'Достопримечательность',
    'excursion': 'Экскурсия',
    'museum': 'Музей',
    'park': 'Парк',
    'event': 'Событие',
    'nature': 'Природа',
    'restaurant': 'Ресторан',
    'cafe': 'Кафе',
    'bar': 'Бар',
    'fastfood': 'Фастфуд',
    'breakfast': 'Завтрак',
    'lunch': 'Обед',
    'dinner': 'Ужин',
    'mall': 'Торговый центр',
    'market': 'Рынок',
    'souvenirs': 'Сувениры',
    'shopping_center': 'Торговый центр',
    'walk': 'Прогулка',
    'beach': 'Пляж',
    'sport': 'Спорт',
    'entertainment': 'Развлечения',
    'viewpoint': 'Смотровая',
    'historic': 'Историческое место',
    'architecture': 'Архитектура',
    'gallery': 'Галерея',
  };

  if (key.isEmpty) return '';
  return labels[key] ?? _capitalizeFirst(raw.trim());
}

String _capitalizeFirst(String value) {
  if (value.isEmpty) return value;
  return '${value[0].toUpperCase()}${value.substring(1)}';
}
