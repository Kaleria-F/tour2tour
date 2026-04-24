import { FormEvent, useEffect, useMemo, useState } from 'react';

import {
  createPlace,
  decideCandidate,
  deleteCandidate,
  deletePlace,
  getMe,
  getStoredToken,
  listCandidates,
  listImportJobs,
  listPlaces,
  listTagCatalog,
  login,
  setStoredToken,
  suggestCities,
  updatePlace,
  uploadImportCsv,
  uploadPlaceImage,
  verify2fa,
} from './api';
import type {
  AdminImportJob,
  AdminPlace,
  AdminPlaceCandidate,
  AdminTagCatalogItem,
  CitySuggestion,
  UserMe,
} from './types';

type TabKey = 'places' | 'candidates' | 'imports';

type Option = {
  value: string;
  label: string;
};

type PlaceFormState = {
  name: string;
  city: string;
  address: string;
  image_url: string;
  category: string;
  subcategory: string;
  source: string;
  price_level: string;
  description: string;
  rating: string;
  tags: Record<string, number>;
};

const CATEGORY_OPTIONS: Array<Option & { subcategories: Option[] }> = [
  {
    value: 'place',
    label: 'Место',
    subcategories: [
      { value: 'museum', label: 'Музей' },
      { value: 'park', label: 'Парк' },
      { value: 'landmark', label: 'Достопримечательность' },
      { value: 'gallery', label: 'Галерея' },
      { value: 'theatre', label: 'Театр' },
      { value: 'embankment', label: 'Набережная' },
      { value: 'architecture', label: 'Архитектура' },
    ],
  },
  {
    value: 'food',
    label: 'Еда и гастрономия',
    subcategories: [
      { value: 'restaurant', label: 'Ресторан' },
      { value: 'cafe', label: 'Кафе' },
      { value: 'bar', label: 'Бар' },
      { value: 'food_market', label: 'Фуд-маркет' },
    ],
  },
  {
    value: 'activity',
    label: 'Активность',
    subcategories: [
      { value: 'walk', label: 'Прогулка' },
      { value: 'sport', label: 'Спорт' },
      { value: 'kids', label: 'С детьми' },
      { value: 'quest', label: 'Квест/аттракцион' },
    ],
  },
  {
    value: 'stay',
    label: 'Проживание',
    subcategories: [
      { value: 'hotel', label: 'Отель' },
      { value: 'hostel', label: 'Хостел' },
      { value: 'apartment', label: 'Апартаменты' },
    ],
  },
];

const SOURCE_OPTIONS: Option[] = [
  { value: 'manual', label: 'Ручное добавление' },
  { value: 'csv', label: 'CSV импорт' },
  { value: 'open_data', label: 'Открытые данные' },
  { value: 'partner', label: 'Партнерский источник' },
  { value: 'ai_agent', label: 'ИИ-агент' },
];

const PRICE_OPTIONS: Option[] = [
  { value: '', label: '-' },
  { value: 'economy', label: 'Бюджетно' },
  { value: 'middle', label: 'Средний чек' },
  { value: 'premium', label: 'Премиум' },
];

const IMPORT_KIND_OPTIONS: Option[] = [
  { value: 'place', label: 'Места' },
  { value: 'food', label: 'Гастрономия' },
  { value: 'activity', label: 'Активности' },
  { value: 'stay', label: 'Проживание' },
];

const FALLBACK_TAG_OPTIONS: AdminTagCatalogItem[] = [
  { key: 'history', label: 'История', group: 'interest', color: 'tag-blue', description: 'Исторические места и сюжеты.' },
  { key: 'culture', label: 'Культура', group: 'interest', color: 'tag-violet', description: 'Культурные пространства и локальные традиции.' },
  { key: 'museums', label: 'Музеи', group: 'interest', color: 'tag-amber', description: 'Музеи, выставки и экспозиции.' },
  { key: 'architecture', label: 'Архитектура', group: 'interest', color: 'tag-cyan', description: 'Архитектурно значимые объекты.' },
  { key: 'nature', label: 'Природа', group: 'interest', color: 'tag-green', description: 'Парки, сады и природные точки.' },
  { key: 'food', label: 'Гастрономия', group: 'interest', color: 'tag-red', description: 'Еда, локальная кухня и гастроточки.' },
  { key: 'active', label: 'Активный отдых', group: 'interest', color: 'tag-orange', description: 'Прогулки, спорт и активности.' },
  { key: 'shopping', label: 'Шопинг', group: 'interest', color: 'tag-cyan', description: 'Покупки и торговые точки.' },
  { key: 'photo', label: 'Фотолокации', group: 'interest', color: 'tag-amber', description: 'Видовые и фотогеничные места.' },
  { key: 'nightlife', label: 'Ночная жизнь', group: 'interest', color: 'tag-purple', description: 'Вечерние и ночные активности.' },
  { key: 'hidden', label: 'Необычные места', group: 'interest', color: 'tag-green', description: 'Небанальные hidden gems.' },
  { key: 'family', label: 'Семейный отдых', group: 'audience', color: 'tag-pink', description: 'Подходит для поездок с семьей.' },
  { key: 'romantic', label: 'Романтика', group: 'trip_format', color: 'tag-rose', description: 'Подходит для романтических маршрутов.' },
  { key: 'calm', label: 'Спокойный формат', group: 'trip_format', color: 'tag-green', description: 'Неспешный формат поездки.' },
  { key: 'active_format', label: 'Активный формат', group: 'trip_format', color: 'tag-orange', description: 'Активный сценарий поездки.' },
  { key: 'intense', label: 'Насыщенный формат', group: 'trip_format', color: 'tag-red', description: 'Плотный и насыщенный сценарий.' },
  { key: 'friends', label: 'С друзьями', group: 'audience', color: 'tag-violet', description: 'Подходит для компании друзей.' },
  { key: 'solo', label: 'Соло', group: 'audience', color: 'tag-blue', description: 'Подходит для одного путешественника.' },
  { key: 'couple', label: 'Для пары', group: 'audience', color: 'tag-rose', description: 'Подходит для поездки вдвоем.' },
  { key: 'landmark', label: 'Знаковое место', group: 'system', color: 'tag-cyan', description: 'Главная точка притяжения в городе.' },
  { key: 'walk', label: 'Для прогулки', group: 'system', color: 'tag-green', description: 'Удобно для пешего маршрута.' },
  { key: 'city', label: 'Городской опыт', group: 'system', color: 'tag-default', description: 'Часть знакомства с городом.' },
  { key: 'attraction', label: 'Точка притяжения', group: 'system', color: 'tag-amber', description: 'Яркая точка интереса.' },
  { key: 'cafe', label: 'Кафе-формат', group: 'system', color: 'tag-red', description: 'Подходит для короткой гастроостановки.' },
];

const EMPTY_FORM: PlaceFormState = {
  name: '',
  city: '',
  address: '',
  image_url: '',
  category: 'place',
  subcategory: 'museum',
  source: 'manual',
  price_level: '',
  description: '',
  rating: '',
  tags: {},
};

function normalizeTags(tags: Record<string, number>) {
  return Object.fromEntries(Object.entries(tags).filter(([, weight]) => weight > 0));
}

function formatCategory(category: string) {
  return CATEGORY_OPTIONS.find((item) => item.value === category)?.label ?? category;
}

function formatSubcategory(category: string, subcategory?: string | null) {
  if (!subcategory) return '-';
  return (
    CATEGORY_OPTIONS.find((item) => item.value === category)?.subcategories.find(
      (item) => item.value === subcategory,
    )?.label ?? subcategory
  );
}

function formatSource(source: string) {
  return SOURCE_OPTIONS.find((item) => item.value === source)?.label ?? source;
}

function formatPrice(priceLevel?: string | null) {
  if (!priceLevel) return '-';
  return PRICE_OPTIONS.find((item) => item.value === priceLevel)?.label ?? priceLevel;
}

function getCandidateValue(candidate: AdminPlaceCandidate, key: string) {
  const normalized = (candidate.normalized_json ?? {}) as Record<string, unknown>;
  const payload = (candidate.payload_json ?? {}) as Record<string, unknown>;
  return normalized[key] ?? payload[key];
}

function getTagLabel(key: string, catalog: AdminTagCatalogItem[]) {
  return catalog.find((item) => item.key === key)?.label ?? key;
}

function getTagColor(key: string, catalog: AdminTagCatalogItem[]) {
  return catalog.find((item) => item.key === key)?.color ?? 'tag-default';
}

function isPlaceFieldMissing(
  place: AdminPlace,
  field: 'name' | 'city' | 'address' | 'category' | 'source' | 'price_level' | 'rating' | 'image_url',
) {
  const value = place[field];
  return value == null || String(value).trim() === '';
}

export function App() {
  const [token, setToken] = useState<string | null>(() => getStoredToken());
  const [me, setMe] = useState<UserMe | null>(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');
  const [challengeId, setChallengeId] = useState('');
  const [tab, setTab] = useState<TabKey>('places');
  const [places, setPlaces] = useState<AdminPlace[]>([]);
  const [candidates, setCandidates] = useState<AdminPlaceCandidate[]>([]);
  const [imports, setImports] = useState<AdminImportJob[]>([]);
  const [placeEditor, setPlaceEditor] = useState<AdminPlace | null>(null);
  const [placeForm, setPlaceForm] = useState<PlaceFormState>(EMPTY_FORM);
  const [selectedPlaceIds, setSelectedPlaceIds] = useState<string[]>([]);
  const [bulkProcessing, setBulkProcessing] = useState(false);
  const [citySuggestions, setCitySuggestions] = useState<CitySuggestion[]>([]);
  const [tagCatalog, setTagCatalog] = useState<AdminTagCatalogItem[]>(FALLBACK_TAG_OPTIONS);

  const selectedCategory = useMemo(
    () => CATEGORY_OPTIONS.find((item) => item.value === placeForm.category) ?? CATEGORY_OPTIONS[0],
    [placeForm.category],
  );

  useEffect(() => {
    if (!token) {
      setMe(null);
      return;
    }
    void refreshAll(token);
  }, [token]);

  useEffect(() => {
    if (!placeEditor) {
      setPlaceForm(EMPTY_FORM);
      return;
    }
    setPlaceForm({
      name: placeEditor.name ?? '',
      city: placeEditor.city ?? '',
      address: placeEditor.address ?? '',
      image_url: placeEditor.image_url ?? '',
      category: placeEditor.category ?? 'place',
      subcategory: placeEditor.subcategory ?? 'museum',
      source: placeEditor.source ?? 'manual',
      price_level: placeEditor.price_level ?? '',
      description: placeEditor.description ?? '',
      rating: placeEditor.rating != null ? String(placeEditor.rating) : '',
      tags: placeEditor.tags ?? {},
    });
  }, [placeEditor]);

  useEffect(() => {
    const query = placeForm.city.trim();
    if (query.length < 2) {
      setCitySuggestions([]);
      return;
    }

    const timer = window.setTimeout(() => {
      void suggestCities(query, token ?? undefined)
        .then(setCitySuggestions)
        .catch(() => setCitySuggestions([]));
    }, 180);

    return () => window.clearTimeout(timer);
  }, [placeForm.city, token]);

  async function refreshAll(activeToken: string) {
    setLoading(true);
    setError('');
    try {
      const user = await getMe(activeToken);
      setMe(user);
      if (user.role !== 'admin') {
        setPlaces([]);
        setCandidates([]);
        setImports([]);
        return;
      }
      const [placeItems, candidateItems, importItems] = await Promise.all([
        listPlaces(activeToken),
        listCandidates(activeToken),
        listImportJobs(activeToken),
      ]);
      try {
        const catalog = await listTagCatalog(activeToken);
        setTagCatalog(catalog.length > 0 ? catalog : FALLBACK_TAG_OPTIONS);
      } catch {
        setTagCatalog(FALLBACK_TAG_OPTIONS);
      }
      setPlaces(placeItems);
      setCandidates(candidateItems);
      setImports(importItems);
      setSelectedPlaceIds((current) => current.filter((id) => placeItems.some((place) => place.id === id)));
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Ошибка загрузки');
    } finally {
      setLoading(false);
    }
  }

  async function handleLogin(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setError('');
    const form = new FormData(event.currentTarget);
    const email = String(form.get('email') || '');
    const password = String(form.get('password') || '');
    try {
      const result = await login(email, password);
      if (result.requires_2fa && result.challenge_id) {
        setChallengeId(result.challenge_id);
        return;
      }
      if (!result.access_token) {
        throw new Error('Сервер не вернул access token');
      }
      setStoredToken(result.access_token);
      setToken(result.access_token);
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Ошибка входа');
    }
  }

  async function handle2fa(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setError('');
    const form = new FormData(event.currentTarget);
    const code = String(form.get('code') || '');
    try {
      const result = await verify2fa(challengeId, code);
      if (!result.access_token) {
        throw new Error('Сервер не вернул access token');
      }
      setStoredToken(result.access_token);
      setToken(result.access_token);
      setChallengeId('');
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Ошибка подтверждения');
    }
  }

  async function handleSavePlace(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (!token) return;
    setError('');
    const form = new FormData(event.currentTarget);
    try {
      const imageFile = form.get('image_file');
      let imageUrl = placeForm.image_url.trim();
      if (imageFile instanceof File && imageFile.size > 0) {
        const uploaded = await uploadPlaceImage(token, imageFile);
        imageUrl = uploaded.url;
      }

      const payload = {
        source: placeForm.source,
        status: 'approved',
        name: placeForm.name.trim(),
        city: placeForm.city.trim(),
        address: placeForm.address.trim(),
        image_url: imageUrl || null,
        category: placeForm.category,
        subcategory: placeForm.subcategory,
        description: placeForm.description.trim(),
        price_level: placeForm.price_level || null,
        rating: placeForm.rating ? Number(placeForm.rating) : null,
        tags: normalizeTags(placeForm.tags),
      };

      if (placeEditor) {
        await updatePlace(token, placeEditor.id, payload);
      } else {
        await createPlace(token, payload);
      }
      setPlaceEditor(null);
      setPlaceForm(EMPTY_FORM);
      await refreshAll(token);
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Ошибка сохранения места');
    }
  }

  async function handleDeletePlace(id: string) {
    if (!token) return;
    try {
      await deletePlace(token, id);
      setPlaces((current) => current.filter((place) => place.id !== id));
      setSelectedPlaceIds((current) => current.filter((item) => item !== id));
      if (placeEditor?.id === id) {
        setPlaceEditor(null);
        setPlaceForm(EMPTY_FORM);
      }
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Ошибка удаления');
    }
  }

  async function handleDeleteSelectedPlaces() {
    if (!token || selectedPlaceIds.length === 0) return;
    setBulkProcessing(true);
    setError('');
    try {
      for (const id of selectedPlaceIds) {
        await deletePlace(token, id);
      }
      setPlaces((current) => current.filter((place) => !selectedPlaceIds.includes(place.id)));
      setSelectedPlaceIds([]);
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Ошибка массового удаления');
    } finally {
      setBulkProcessing(false);
    }
  }

  async function handleCandidateDecision(id: string, status: 'approved' | 'rejected') {
    if (!token) return;
    try {
      await decideCandidate(token, id, status);
      setCandidates((current) => current.filter((candidate) => candidate.id !== id));
      const [placeItems, importItems] = await Promise.all([listPlaces(token), listImportJobs(token)]);
      setPlaces(placeItems);
      setImports(importItems);
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Ошибка модерации');
    }
  }

  async function handleDeleteCandidate(id: string) {
    if (!token) return;
    try {
      await deleteCandidate(token, id);
      setCandidates((current) => current.filter((candidate) => candidate.id !== id));
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Ошибка удаления кандидата');
    }
  }

  async function handleApproveAllCandidates() {
    if (!token || candidates.length === 0) return;
    setBulkProcessing(true);
    setError('');
    try {
      for (const candidate of candidates) {
        await decideCandidate(token, candidate.id, 'approved');
      }
      setCandidates([]);
      const [placeItems, importItems] = await Promise.all([listPlaces(token), listImportJobs(token)]);
      setPlaces(placeItems);
      setImports(importItems);
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Ошибка массового одобрения');
    } finally {
      setBulkProcessing(false);
    }
  }

  async function handleImport(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (!token || !me) return;
    const form = new FormData(event.currentTarget);
    const file = form.get('file');
    if (!(file instanceof File)) {
      setError('Нужно выбрать CSV файл');
      return;
    }
    try {
      await uploadImportCsv(
        token,
        file,
        String(form.get('source') || 'csv'),
        String(form.get('kind') || 'place'),
        me.email || me.phone || 'admin',
      );
      await refreshAll(token);
      event.currentTarget.reset();
      setTab('candidates');
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Ошибка импорта');
    }
  }

  function togglePlaceSelection(id: string) {
    setSelectedPlaceIds((current) =>
      current.includes(id) ? current.filter((item) => item !== id) : [...current, id],
    );
  }

  function toggleAllPlaces() {
    if (selectedPlaceIds.length === places.length) {
      setSelectedPlaceIds([]);
      return;
    }
    setSelectedPlaceIds(places.map((place) => place.id));
  }

  const isAdmin = me?.role === 'admin';
  const title = useMemo(() => {
    switch (tab) {
      case 'places':
        return 'Каталог мест';
      case 'candidates':
        return 'Кандидаты на модерацию';
      case 'imports':
        return 'Импорт CSV';
    }
  }, [tab]);

  if (!token) {
    return (
      <div className="auth-shell">
        <div className="auth-card">
          <div className="brand">Tour2Tour Admin</div>
          <h1>{challengeId ? 'Подтверждение входа' : 'Вход администратора'}</h1>
          <p>{challengeId ? 'Введите TOTP-код' : 'Используйте отдельную учетную запись администратора.'}</p>
          {error && <div className="error">{error}</div>}
          {!challengeId ? (
            <form onSubmit={handleLogin} className="stack">
              <input name="email" placeholder="Email" required />
              <input name="password" type="password" placeholder="Пароль" required />
              <button type="submit">Войти</button>
            </form>
          ) : (
            <form onSubmit={handle2fa} className="stack">
              <input name="code" placeholder="TOTP код" required />
              <button type="submit">Подтвердить</button>
            </form>
          )}
        </div>
      </div>
    );
  }

  return (
    <div className="app-shell">
      <main className="content">
        <div className="topbar">
          <div>
            <h1>{title}</h1>
            <div className="muted">{isAdmin ? 'Роль администратора подтверждена' : 'Доступ ограничен'}</div>
          </div>
          <div className="topbar-actions">
            <div className="nav nav-inline">
              <button className={tab === 'places' ? 'nav-active' : ''} onClick={() => setTab('places')}>
                Места
              </button>
              <button className={tab === 'candidates' ? 'nav-active' : ''} onClick={() => setTab('candidates')}>
                Кандидаты
              </button>
              <button className={tab === 'imports' ? 'nav-active' : ''} onClick={() => setTab('imports')}>
                Импорт
              </button>
            </div>
            <button className="ghost" onClick={() => token && refreshAll(token)}>
              Обновить
            </button>
            <button
              className="ghost"
              onClick={() => {
                setStoredToken(null);
                setToken(null);
              }}
            >
              Выйти
            </button>
          </div>
        </div>

        {error && <div className="error">{error}</div>}
        {loading && <div className="card">Загрузка...</div>}
        {!loading && !isAdmin && <div className="card">Доступ запрещен. Нужна роль admin.</div>}

        {!loading && isAdmin && (
          <>
            {tab === 'places' && (
              <div className="places-layout">
                <div className="card">
                  <div className="section-head">
                    <h2>Места</h2>
                    <div className="row">
                      <span className="muted small">Всего: {places.length}</span>
                      {selectedPlaceIds.length > 0 && (
                        <button className="danger" onClick={handleDeleteSelectedPlaces} disabled={bulkProcessing}>
                          Удалить выбранные ({selectedPlaceIds.length})
                        </button>
                      )}
                      <button
                        onClick={() => {
                          setPlaceEditor(null);
                          setPlaceForm(EMPTY_FORM);
                        }}
                      >
                        Новое место
                      </button>
                    </div>
                  </div>

                  <div className="table-wrap">
                    <table className="places-table">
                      <thead>
                        <tr>
                          <th>
                            <input
                              type="checkbox"
                              checked={places.length > 0 && selectedPlaceIds.length === places.length}
                              onChange={toggleAllPlaces}
                            />
                          </th>
                          <th>Название</th>
                          <th>Город</th>
                          <th>Категория</th>
                          <th>Источник</th>
                          <th>Цена</th>
                          <th>Рейтинг</th>
                          <th>Фото</th>
                          <th>Теги</th>
                          <th></th>
                        </tr>
                      </thead>
                      <tbody>
                        {places.map((place) => (
                          <tr key={place.id}>
                            <td>
                              <input
                                type="checkbox"
                                checked={selectedPlaceIds.includes(place.id)}
                                onChange={() => togglePlaceSelection(place.id)}
                              />
                            </td>
                            <td
                              className={
                                isPlaceFieldMissing(place, 'name') || isPlaceFieldMissing(place, 'address')
                                  ? 'missing-cell'
                                  : ''
                              }
                            >
                              <div className="cell-title">{place.name || '-'}</div>
                              <div className="muted small">{place.address || 'Адрес не заполнен'}</div>
                            </td>
                            <td className={isPlaceFieldMissing(place, 'city') ? 'missing-cell' : ''}>
                              {place.city || '-'}
                            </td>
                            <td className={isPlaceFieldMissing(place, 'category') ? 'missing-cell' : ''}>
                              <div>{formatCategory(place.category)}</div>
                              <div className="muted small">{formatSubcategory(place.category, place.subcategory)}</div>
                            </td>
                            <td className={isPlaceFieldMissing(place, 'source') ? 'missing-cell' : ''}>
                              {formatSource(place.source)}
                            </td>
                            <td className={!place.price_level ? 'missing-cell' : ''}>{formatPrice(place.price_level)}</td>
                            <td className={place.rating == null ? 'missing-cell' : ''}>{place.rating ?? '-'}</td>
                            <td className={isPlaceFieldMissing(place, 'image_url') ? 'missing-cell' : ''}>
                              {place.image_url ? (
                                <img className="place-thumb" src={place.image_url} alt={place.name} />
                              ) : (
                                'Нет фото'
                              )}
                            </td>
                            <td className={!Object.keys(place.tags || {}).length ? 'missing-cell' : ''}>
                              <div className="tag-cloud">
                                {Object.entries(place.tags || {}).length > 0 ? (
                                  Object.entries(place.tags || {}).map(([key, weight]) => (
                                    <span key={key} className={`tag-pill ${getTagColor(key, tagCatalog)}`}>
                                      {getTagLabel(key, tagCatalog)}: {weight}
                                    </span>
                                  ))
                                ) : (
                                  <span className="muted small">Теги не заданы</span>
                                )}
                              </div>
                            </td>
                            <td>
                              <div className="row">
                                <button className="ghost" onClick={() => setPlaceEditor(place)}>
                                  Изменить
                                </button>
                                <button className="danger" onClick={() => handleDeletePlace(place.id)}>
                                  Удалить
                                </button>
                              </div>
                            </td>
                          </tr>
                        ))}
                      </tbody>
                    </table>
                  </div>
                </div>

                <div className="card">
                  <h2>{placeEditor ? 'Редактирование места' : 'Создание места'}</h2>
                  <form className="stack" onSubmit={handleSavePlace}>
                    <input
                      value={placeForm.name}
                      onChange={(event) => setPlaceForm((current) => ({ ...current, name: event.target.value }))}
                      placeholder="Название"
                      required
                    />
                    <input
                      value={placeForm.city}
                      onChange={(event) => setPlaceForm((current) => ({ ...current, city: event.target.value }))}
                      placeholder="Город"
                      list="city-suggestions"
                      required
                    />
                    <datalist id="city-suggestions">
                      {citySuggestions.map((suggestion) => (
                        <option
                          key={`${suggestion.city}-${suggestion.region ?? ''}`}
                          value={suggestion.city}
                          label={suggestion.display_name}
                        />
                      ))}
                    </datalist>
                    <input
                      value={placeForm.address}
                      onChange={(event) => setPlaceForm((current) => ({ ...current, address: event.target.value }))}
                      placeholder="Адрес"
                    />
                    <input
                      value={placeForm.image_url}
                      onChange={(event) => setPlaceForm((current) => ({ ...current, image_url: event.target.value }))}
                      placeholder="Ссылка на фото (если уже есть)"
                    />
                    <input name="image_file" type="file" accept="image/*" />
                    {placeForm.image_url && <img className="form-image-preview" src={placeForm.image_url} alt="preview" />}

                    <div className="field-group">
                      <label>Категория</label>
                      <div className="chip-group">
                        {CATEGORY_OPTIONS.map((option) => (
                          <button
                            key={option.value}
                            type="button"
                            className={placeForm.category === option.value ? 'chip chip-active' : 'chip'}
                            onClick={() =>
                              setPlaceForm((current) => ({
                                ...current,
                                category: option.value,
                                subcategory: option.subcategories[0]?.value ?? '',
                              }))
                            }
                          >
                            {option.label}
                          </button>
                        ))}
                      </div>
                    </div>

                    <div className="field-group">
                      <label>Подкатегория</label>
                      <div className="chip-group">
                        {selectedCategory.subcategories.map((option) => (
                          <button
                            key={option.value}
                            type="button"
                            className={placeForm.subcategory === option.value ? 'chip chip-active' : 'chip'}
                            onClick={() => setPlaceForm((current) => ({ ...current, subcategory: option.value }))}
                          >
                            {option.label}
                          </button>
                        ))}
                      </div>
                    </div>

                    <div className="field-group">
                      <label>Источник</label>
                      <div className="chip-group">
                        {SOURCE_OPTIONS.map((option) => (
                          <button
                            key={option.value}
                            type="button"
                            className={placeForm.source === option.value ? 'chip chip-active' : 'chip'}
                            onClick={() => setPlaceForm((current) => ({ ...current, source: option.value }))}
                          >
                            {option.label}
                          </button>
                        ))}
                      </div>
                    </div>

                    <div className="field-group">
                      <label>Уровень цены</label>
                      <div className="chip-group">
                        {PRICE_OPTIONS.map((option) => (
                          <button
                            key={option.value || 'empty'}
                            type="button"
                            className={placeForm.price_level === option.value ? 'chip chip-active' : 'chip'}
                            onClick={() => setPlaceForm((current) => ({ ...current, price_level: option.value }))}
                          >
                            {option.label}
                          </button>
                        ))}
                      </div>
                    </div>

                    <input
                      value={placeForm.rating}
                      onChange={(event) => setPlaceForm((current) => ({ ...current, rating: event.target.value }))}
                      placeholder="Рейтинг от 0 до 5"
                    />

                    <textarea
                      rows={4}
                      value={placeForm.description}
                      onChange={(event) => setPlaceForm((current) => ({ ...current, description: event.target.value }))}
                      placeholder="Описание"
                    />

                    <div className="field-group">
                      <label>Теги и веса для рекомендаций</label>
                      <div className="tag-editor">
                        {tagCatalog.map((tag) => {
                          const value = placeForm.tags[tag.key] ?? 0;
                          return (
                            <div key={tag.key} className="tag-editor-row">
                              <div className="tag-editor-copy">
                                <span className={`tag-pill ${tag.color}`}>{tag.label}</span>
                                <span className="muted small">{tag.description}</span>
                              </div>
                              <div className="score-group">
                                {[0, 1, 2, 3, 4, 5].map((score) => (
                                  <button
                                    key={score}
                                    type="button"
                                    className={value === score ? 'score-chip score-chip-active' : 'score-chip'}
                                    onClick={() =>
                                      setPlaceForm((current) => ({
                                        ...current,
                                        tags:
                                          score === 0
                                            ? Object.fromEntries(
                                                Object.entries(current.tags).filter(([key]) => key !== tag.key),
                                              )
                                            : { ...current.tags, [tag.key]: score },
                                      }))
                                    }
                                  >
                                    {score}
                                  </button>
                                ))}
                              </div>
                            </div>
                          );
                        })}
                      </div>
                    </div>

                    <div className="row">
                      <button type="submit">Сохранить</button>
                      {placeEditor && (
                        <button
                          type="button"
                          className="ghost"
                          onClick={() => {
                            setPlaceEditor(null);
                            setPlaceForm(EMPTY_FORM);
                          }}
                        >
                          Сбросить
                        </button>
                      )}
                    </div>
                  </form>
                </div>
              </div>
            )}

            {tab === 'candidates' && (
              <div className="card">
                <div className="section-head">
                  <h2>Кандидаты</h2>
                  <div className="row">
                    <span className="muted small">На модерации: {candidates.length}</span>
                    {candidates.length > 0 && (
                      <button onClick={handleApproveAllCandidates} disabled={bulkProcessing}>
                        Одобрить все
                      </button>
                    )}
                    <button className="ghost" onClick={() => setTab('places')}>
                      Вернуться
                    </button>
                  </div>
                </div>
                <div className="candidate-list">
                  {candidates.map((candidate) => {
                    const tags = (getCandidateValue(candidate, 'tags') as Record<string, number>) || {};
                    const imageUrl = String(getCandidateValue(candidate, 'image_url') || '');
                    const name = String(getCandidateValue(candidate, 'name') || 'Без названия');
                    const city = String(getCandidateValue(candidate, 'city') || '-');
                    const category = String(getCandidateValue(candidate, 'category') || 'place');
                    const subcategory = String(getCandidateValue(candidate, 'subcategory') || '');
                    const description = String(getCandidateValue(candidate, 'description') || '').trim();
                    const address = String(getCandidateValue(candidate, 'address') || '').trim();
                    const sourceRecordId = candidate.source_record_id ? String(candidate.source_record_id) : '';
                    return (
                      <div key={candidate.id} className="candidate-card">
                        <div className="candidate-main">
                          <div className="candidate-head">
                            <strong>{name}</strong>
                            <span className="status-badge">На модерации</span>
                          </div>
                          <div className="muted">
                            {city} · {formatCategory(category)} ·{' '}
                            {formatSubcategory(category, subcategory)} ·{' '}
                            {formatSource(candidate.source)}
                          </div>
                          {description && <div className="candidate-description">{description}</div>}
                          {imageUrl && <img className="candidate-preview" src={imageUrl} alt="candidate" />}
                          <div className="candidate-grid">
                            <div>
                              <span className="label">Адрес</span>
                              <div>{address || '-'}</div>
                            </div>
                            <div>
                              <span className="label">Цена</span>
                              <div>{formatPrice(String(getCandidateValue(candidate, 'price_level') || ''))}</div>
                            </div>
                            <div>
                              <span className="label">Координаты</span>
                              <div>
                                {String(getCandidateValue(candidate, 'lat') || '-')} / {String(getCandidateValue(candidate, 'lon') || '-')}
                              </div>
                            </div>
                            <div>
                              <span className="label">Запись источника</span>
                              <div>{sourceRecordId || '-'}</div>
                            </div>
                          </div>
                          <div className="tag-cloud">
                            {Object.entries(tags).length > 0 ? (
                              Object.entries(tags).map(([key, weight]) => (
                                <span key={key} className={`tag-pill ${getTagColor(key, tagCatalog)}`}>
                                  {getTagLabel(key, tagCatalog)}: {weight}
                                </span>
                              ))
                            ) : (
                              <span className="muted small">Теги не заданы</span>
                            )}
                          </div>
                        </div>
                        <div className="candidate-actions">
                          <button onClick={() => handleCandidateDecision(candidate.id, 'approved')}>Одобрить</button>
                          <button className="ghost" onClick={() => handleCandidateDecision(candidate.id, 'rejected')}>
                            Отклонить
                          </button>
                          <button className="danger" onClick={() => handleDeleteCandidate(candidate.id)}>
                            Удалить
                          </button>
                        </div>
                      </div>
                    );
                  })}
                  {candidates.length === 0 && <div className="item">Кандидатов на модерации нет.</div>}
                </div>
              </div>
            )}

            {tab === 'imports' && (
              <div className="grid-2">
                <div className="card">
                  <h2>Загрузить CSV</h2>
                  <form className="stack" onSubmit={handleImport}>
                    <div className="field-group">
                      <label>Источник</label>
                      <div className="chip-group">
                        {SOURCE_OPTIONS.map((option) => (
                          <label key={option.value} className="chip chip-radio">
                            <input type="radio" name="source" value={option.value} defaultChecked={option.value === 'csv'} />
                            {option.label}
                          </label>
                        ))}
                      </div>
                    </div>

                    <div className="field-group">
                      <label>Тип данных</label>
                      <div className="chip-group">
                        {IMPORT_KIND_OPTIONS.map((option) => (
                          <label key={option.value} className="chip chip-radio">
                            <input type="radio" name="kind" value={option.value} defaultChecked={option.value === 'place'} />
                            {option.label}
                          </label>
                        ))}
                      </div>
                    </div>

                    <input name="file" type="file" accept=".csv,text/csv" required />
                    <div className="muted small">
                      Поддерживаются CSV в UTF-8 или CP1251, разделители: запятая, точка с запятой или tab.
                    </div>
                    <button type="submit">Загрузить</button>

                    <div className="field-group">
                      <label>Справочник тегов</label>
                      <div className="catalog-grid">
                        {tagCatalog.map((tag) => (
                          <div key={tag.key} className="catalog-item">
                            <div className="row">
                              <span className={`tag-pill ${tag.color}`}>{tag.label}</span>
                              <span className="muted small">{tag.key}</span>
                            </div>
                            <div className="muted small">{tag.description}</div>
                          </div>
                        ))}
                      </div>
                    </div>
                  </form>
                </div>
                <div className="card">
                  <h2>История импортов</h2>
                  <div className="list">
                    {imports.map((job) => (
                      <div key={job.id} className="item">
                        <div>
                          <strong>{job.file_name || 'Без файла'}</strong>
                          <div className="muted">
                            {formatSource(job.source)} · {formatCategory(job.kind)} · {job.status}
                          </div>
                          {job.stats_json && (
                            <div className="muted small">
                              Всего: {String(job.stats_json.rows_total || 0)} · Создано: {String(job.stats_json.candidates_created || 0)} · Ошибок: {String(job.stats_json.rows_failed || 0)}
                            </div>
                          )}
                        </div>
                      </div>
                    ))}
                  </div>
                </div>
              </div>
            )}
          </>
        )}
      </main>
    </div>
  );
}
