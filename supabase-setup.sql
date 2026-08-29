-- ============================================================
-- 이벤트 사이트(event.suayona.com) Supabase 설정
-- Supabase 프로젝트의 SQL Editor 에서 실행하세요.
--
-- 먼저 Storage 메뉴에서 Public 버킷 두 개를 만들어 두어야 합니다:
--   · event-images    — 일정에 첨부하는 사진 (로그인한 사람만 업로드)
--   · gallery-uploads — 갤러리 탭 (누구나 업로드), File size limit 을 100MB 로
--
-- 이벤트를 새로 만들 때 따로 할 일은 없습니다.
-- 허브 페이지의 "+ 새 이벤트 만들기" 버튼이 event_meta 에 행을 넣으면,
-- /e/?slug=주소 페이지가 날짜 탭까지 알아서 만들어 줍니다.
-- ============================================================


-- ============================================================
-- 1) events — 날짜별 일정 항목
-- ============================================================
create table if not exists events (
  id bigint generated always as identity primary key,
  event_id text not null,             -- 어느 이벤트인지 (event_meta.event_id 와 같은 값)
  panel text not null,                -- 며칟날 탭인지 ('d1', 'd2', ...)
  sort_order int not null default 0,  -- 같은 날 안에서의 순서
  time text,                          -- 예: '09:00-09:30'
  title text not null,                -- 예: '아침식사'
  detail text,                        -- 예: '식당 1층' (줄바꿈 그대로 표시됨)
  image_url text,                     -- 첨부 사진
  taken_at timestamptz,               -- 사진 EXIF 촬영 일시 (사진 파일은 건드리지 않고 화면에만 표시)
  location_name text,                 -- 사진 EXIF 위치를 지명으로 바꾼 값
  created_at timestamptz default now()
);

alter table events enable row level security;

-- 일정은 누구나 볼 수 있음
create policy "public can read events"
  on events for select
  using (true);

-- 추가/수정/삭제는 로그인한 관리자만
create policy "authenticated can write events"
  on events for all
  using (auth.role() = 'authenticated')
  with check (auth.role() = 'authenticated');


-- ============================================================
-- 2) event_meta — 이벤트 한 건의 정보 (이벤트당 한 행)
-- ============================================================
create table if not exists event_meta (
  event_id text primary key,          -- 주소에 쓰이는 슬러그 (예: '2027-01-camp')
  icon text,                          -- 헤더 아이콘 이모지
  org_name text,                      -- 큰 제목 (예: '수아연아랑')
  event_name text,                    -- 부제목
  date_range_text text,               -- 날짜 표시 문구
  start_date date,                    -- 이 두 날짜로 날짜 탭을 자동 생성함
  end_date date,
  notice_content text,                -- (예전 '노트' 탭용 — 지금은 custom_tabs 를 씀)
  is_public boolean not null default true,  -- false 면 로그인해야 보임
  updated_at timestamptz default now()
);

alter table event_meta enable row level security;

-- 공개 이벤트는 누구나, 비공개는 로그인한 사람만.
-- 목록에서 숨기는 데 그치지 않고 주소를 직접 열어도 막힘.
create policy "public can read public event_meta"
  on event_meta for select
  using (is_public = true or auth.role() = 'authenticated');

create policy "authenticated can write event_meta"
  on event_meta for all
  using (auth.role() = 'authenticated')
  with check (auth.role() = 'authenticated');


-- ============================================================
-- 3) gallery_media — 갤러리 탭 (누구나 올릴 수 있는 공용 앨범)
-- ============================================================
create table if not exists gallery_media (
  id bigint generated always as identity primary key,
  event_id text not null,
  media_url text not null,
  media_type text not null,           -- 'image' 또는 'video'
  taken_at timestamptz,
  location_name text,
  created_at timestamptz default now()
);

alter table gallery_media enable row level security;

create policy "public can read gallery_media"
  on gallery_media for select
  using (true);

-- 로그인 없이도 올릴 수 있음 (용량은 페이지에서 걸러냄)
create policy "anyone can insert gallery_media"
  on gallery_media for insert
  with check (true);

create policy "authenticated can update gallery_media"
  on gallery_media for update
  using (auth.role() = 'authenticated')
  with check (auth.role() = 'authenticated');

-- 부적절한 업로드를 정리할 수 있도록 삭제는 관리자만
create policy "authenticated can delete gallery_media"
  on gallery_media for delete
  using (auth.role() = 'authenticated');


-- ============================================================
-- 4) custom_tabs — 날짜 탭 외에 직접 만드는 자유 서식 탭
--    관리 페이지의 "커스텀 탭 관리"에서 추가/수정/삭제
--    공개 페이지에서는 날짜 탭과 갤러리 탭 사이에 sort_order 순으로 들어감
-- ============================================================
create table if not exists custom_tabs (
  id bigint generated always as identity primary key,
  event_id text not null,
  label text not null,                -- 탭 이름 (이모지 가능, 예: '🧩 조편성')
  content text,                       -- '# 제목' / '## 소제목' / 세로선(|) 표 / ![](사진주소)
  sort_order int not null default 0,
  created_at timestamptz default now()
);

alter table custom_tabs enable row level security;

create policy "public can read custom_tabs"
  on custom_tabs for select
  using (true);

create policy "authenticated can write custom_tabs"
  on custom_tabs for all
  using (auth.role() = 'authenticated')
  with check (auth.role() = 'authenticated');


-- ============================================================
-- 5) Storage 정책
-- ============================================================
-- event-images: 일정 사진 — 관리자만 올리고 지울 수 있음
create policy "authenticated can upload event images"
  on storage.objects for insert
  with check (bucket_id = 'event-images' and auth.role() = 'authenticated');

create policy "authenticated can update event images"
  on storage.objects for update
  using (bucket_id = 'event-images' and auth.role() = 'authenticated');

create policy "authenticated can delete event images"
  on storage.objects for delete
  using (bucket_id = 'event-images' and auth.role() = 'authenticated');

-- gallery-uploads: 갤러리 — 누구나 올리고, 지우는 건 관리자만
create policy "anyone can upload to gallery bucket"
  on storage.objects for insert
  with check (bucket_id = 'gallery-uploads');

create policy "authenticated can delete from gallery bucket"
  on storage.objects for delete
  using (bucket_id = 'gallery-uploads' and auth.role() = 'authenticated');


-- ============================================================
-- 참고: 이미 운영 중인 프로젝트에 뒤늦게 추가된 것들
-- 위 create table 은 새 프로젝트용이라 기존 테이블에는 적용되지 않습니다.
-- 아직 실행하지 않은 게 있다면 이것만 따로 실행하세요.
-- ============================================================
-- alter table events      add column if not exists image_url text;
-- alter table events      add column if not exists taken_at timestamptz;
-- alter table events      add column if not exists location_name text;
-- alter table gallery_media add column if not exists taken_at timestamptz;
-- alter table gallery_media add column if not exists location_name text;
-- alter table event_meta  add column if not exists start_date date;
-- alter table event_meta  add column if not exists end_date date;
-- alter table event_meta  add column if not exists notice_content text;
-- alter table event_meta  add column if not exists is_public boolean not null default true;
--
-- -- is_public 을 추가했다면 읽기 정책도 새로 걸어야 비공개가 실제로 막힙니다
-- drop policy if exists "public can read event_meta" on event_meta;
-- create policy "public can read public event_meta"
--   on event_meta for select
--   using (is_public = true or auth.role() = 'authenticated');
