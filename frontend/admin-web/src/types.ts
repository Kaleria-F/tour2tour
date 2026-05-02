export type TokenResponse = {
  access_token?: string | null;
  requires_2fa?: boolean;
  challenge_id?: string | null;
  available_factors?: string[];
};

export type UserMe = {
  id: number;
  email?: string | null;
  phone?: string | null;
  role: string;
  is_2fa_enabled: boolean;
};

export type AdminPlace = {
  id: string;
  source: string;
  status: string;
  name: string;
  description?: string | null;
  image_url?: string | null;
  country?: string | null;
  city: string;
  address?: string | null;
  lat?: number | null;
  lon?: number | null;
  category: string;
  subcategory?: string | null;
  price_level?: string | null;
  avg_visit_duration_min?: number | null;
  rating?: number | null;
  reviews_count: number;
  tags: Record<string, number>;
};

export type AdminPlaceListResponse = {
  items: AdminPlace[];
  total: number;
};

export type AdminStoryPlace = {
  id: string;
  name: string;
  city: string;
  image_url?: string | null;
  address?: string | null;
  category: string;
  subcategory?: string | null;
  rating?: number | null;
  description?: string | null;
};

export type AdminStory = {
  id: string;
  title: string;
  cover_image_url?: string | null;
  image_url: string;
  body_text?: string | null;
  place_id?: string | null;
  sort_order: number;
  is_active: boolean;
  place?: AdminStoryPlace | null;
};

export type AdminPlaceCandidate = {
  id: string;
  source: string;
  source_record_id?: string | null;
  status: string;
  payload_json: Record<string, unknown>;
  normalized_json?: Record<string, unknown> | null;
  validation_score?: number | null;
  notes?: string | null;
};

export type AdminImportJob = {
  id: string;
  source: string;
  kind: string;
  status: string;
  file_name?: string | null;
  created_by?: string | null;
  stats_json?: Record<string, unknown>;
};

export type AdminTagCatalogItem = {
  key: string;
  label: string;
  group: string;
  color: string;
  description: string;
};

export type CitySuggestion = {
  city: string;
  region?: string | null;
  district?: string | null;
  country: string;
  display_name: string;
  lat?: number | null;
  lon?: number | null;
  population?: number | null;
  type?: string | null;
  source: string;
};
