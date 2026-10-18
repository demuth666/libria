# Issue tracker: GitHub

Issue dan spesifikasi untuk repo ini hidup sebagai GitHub issue. Gunakan CLI `gh` untuk semua operasi.

## Konvensi

- **Buat issue**: `gh issue create --title "..." --body "..."`. Gunakan heredoc untuk body multi-baris.
- **Baca issue**: `gh issue view <number> --json number,title,body,labels,comments`.
- **Daftar issue**: `gh issue list --state open --json number,title,body,labels,comments --jq '[.[] | {number, title, body, labels: [.labels[].name], comments: [.comments[].body]}]'` dengan filter `--label` dan `--state` yang sesuai.
- **Jadikan sub-issue dari parent**: `gh issue create --parent <parent> ...`, atau `gh issue edit <parent> --add-sub-issue <child>` setelahnya (`gh` 2.94+). Pada `gh` lama: `gh api --method POST repos/<owner>/<repo>/issues/<parent>/sub_issues -F sub_issue_id=<child-db-id>` (database id, seperti pada **Blocking** di bawah). Tanpa sub-issue, letakkan `Part of #<parent>` di awal body child.
- **Komentar pada issue**: `gh issue comment <number> --body "..."`
- **Pasang / lepas label**: `gh issue edit <number> --add-label "..."` / `--remove-label "..."`
- **Tutup**: `gh issue close <number> --comment "..."`

Repo disimpulkan dari `git remote -v`; `gh` melakukannya otomatis saat dijalankan di dalam clone.

## Pull request sebagai permukaan triage

**PRs as a request surface: no.** _(Set to `yes` if this repo treats external PRs as feature requests; `/triage` reads this flag.)_

Saat diset `yes`, PR mengikuti label dan state yang sama dengan issue, memakai padanan `gh pr`:

- **Baca PR**: `gh pr view <number> --comments` dan `gh pr diff <number>` untuk diff.
- **Daftar PR eksternal untuk triage**: `gh api --paginate 'repos/{owner}/{repo}/pulls?state=open' --jq '.[] | select(.author_association | IN("OWNER","MEMBER","COLLABORATOR") | not) | {number, title, author: .user.login, author_association, labels: [.labels[].name]}'`.
- **Komentar / label / tutup**: `gh pr comment`, `gh pr edit --add-label`/`--remove-label`, `gh pr close`.

GitHub memakai satu ruang nomor untuk issue dan PR, jadi `#42` bisa salah satu: cek dengan `gh pr view 42` lalu fallback ke `gh issue view 42`.

## Saat skill mengatakan "publish to the issue tracker"

Buat GitHub issue.

## Saat skill mengatakan "fetch the relevant ticket"

Baca seperti pada **Baca issue** di atas.

## Operasi wayfinding

Dipakai oleh `/wayfinder`. **Map** adalah satu issue dengan **child** issue sebagai tiket.

- **Map**: satu issue berlabel `wayfinder:map`, berisi body Notes / Decisions-so-far / Fog. `gh issue create --label wayfinder:map`.
- **Child ticket**: issue yang ditautkan ke map sebagai GitHub sub-issue (lihat **Jadikan sub-issue dari parent**). Jika sub-issue tidak tersedia, tambahkan child ke task list di body map dan letakkan `Part of #<map>` di awal body child. Label: `wayfinder:<type>` (`research`/`prototype`/`grilling`/`task`). Setelah diambil, tiket di-assign ke dev yang mengerjakan.
- **Blocking**: dependensi issue native GitHub, representasi kanonik yang terlihat di UI. Tambahkan edge dengan `gh api --method POST repos/<owner>/<repo>/issues/<child>/dependencies/blocked_by -F issue_id=<blocker-db-id>`, dengan `<blocker-db-id>` adalah **database id** numerik blocker (`gh api repos/<owner>/<repo>/issues/<n> --jq .id`, bukan `#number` atau `node_id`). GitHub melaporkan `issue_dependencies_summary.blocked_by` (hanya blocker terbuka, gate yang aktif). Jika dependensi tidak tersedia, fallback ke baris `Blocked by: #<n>, #<n>` di awal body child. Tiket unblocked saat semua blocker ditutup.
- **Frontier query**: daftar child terbuka milik map (`gh issue list --state open`, dibatasi ke sub-issue / task list map), buang yang punya blocker terbuka (`issue_dependencies_summary.blocked_by > 0`, atau issue terbuka di baris `Blocked by`) atau assignee; urutan pertama di map menang.
- **Klaim**: `gh issue edit <n> --add-assignee @me`, tulisan pertama sesi.
- **Selesaikan**: `gh issue comment <n> --body "<jawaban>"`, lalu `gh issue close <n>`, lalu tambahkan pointer konteks (gist + link) ke Decisions-so-far map.
