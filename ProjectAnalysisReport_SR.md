# Izveštaj o analizi projekta — ONRL

**Autor:** Bojan Velickovic, 1070/2024  
**Projekat:** ONRL (One Night RogueLike)  
**Izvor:** https://github.com/nullspeaker/ONRL, main grana  
**Analizirani komit:** `12efcde267c00f120b9b16ad7800fe117dd44d9c`

---

## 1. Pregled projekta

ONRL je nedovršena hobi igra tipa roguelike napisana u C++20, koja koristi SFML multimedijsku biblioteku za grafiku i upravljanje prozorom. Projekat je razvijen tokom jednog peropda i potom napušten. Uprkos tome što nije završen, osnovna funkcionalnost radi: igra prikazuje proceduralno generisanu mapu pećine korišćenjem algoritma binarnog particionisanja prostora (BSP), podržava kretanje igrača i simulira veštačku inteligenciju neprijatelja. Nedostajuće funkcionalnosti uključuju borbu, predmete i korisnički interfejs.

Kod se sastoji od 10 izvornih fajlova sa oko 700 redova koda (bez komentara):

| Fajl | Svrha |
|---|---|
| `main.cpp` | Petlja igre, obrada unosa, renderovanje |
| `console.cpp/h` | SFML konzola za prikazivanje glifa |
| `map.cpp/h` | Generisanje mape i pronalaženje putanje |
| `unit.cpp/h` | Logika igrača i neprijatelja |
| `util.cpp/h` | Logovanje, obrada grešaka, matematičke pomoćne funkcije |
| `colors.h` | Konstante boja |

Projekat je forkovan kako bi se dodale dve nedostajuće `#include` direktive (`<cstdint>` i `<string>`) koje su bile potrebne zbog nekompatibilnosti verzija C++ standarda, kao i da bi se kontrole kretanja promenile sa `hjkl` na `wasd`.

---

## 2. Analiza

### 2.1 Cppcheck

Cppcheck je alat za statičku analizu koji proverava C++ izvorni kod na bagove, stilske probleme i performansne probleme bez potrebe za kompajliranjem koda.

**Upozorenja o nedostajućim headerima** — Cppcheck prijavljuje da ne može da pronađe SFML hedere i standardne bibliotečke hedere kao što su `<iostream>`, `<optional>` i `<cstdint>`. Ova upozorenja se mogu bezbedno ignorisati: Cppcheck ne mora da razrešava bibliotečke hedere da bi izvršio svoju analizu, a projekat se ispravno kompajlira uz cmake.

**Stvarni nalazi:**

- `map.cpp:110-111` — **Redundantni uslov**: kod proverava `if (neighbors[i] < 4)` a zatim `else if (neighbors[i] >= 4)`. Drugi uslov je logička suprotnost prvog i stoga je uvek tačan kada se dostigne. Ovo je mrtav kod — `else if` treba jednostavno da bude `else`.

- `map.cpp:165` i `map.cpp:174` — **Poređenje neoznačenog tipa sa nulom**: uslovi `x >= 0` i `y >= 0` su uvek tačni jer su `x` i `y` tipa `uint32_t` (neoznačeni). Ove provere nemaju nikakvog efekta i sugerišu da je programer razmišljao o promenljivama kao o označenim celim brojevima.

- `unit.cpp:6` — **Provera da li je neoznačeni tip manji od nule**: `if (x < 0 || y < 0 ...)` gde su `x` i `y` neoznačeni. Isti problem kao iznad — provere su uvek netačne i granični uslov koji su trebale da uhvate se nikada ne okida.

- `map.cpp:108-109` — **Nekorišćene promenljive**: `uint32_t x = i%w` i `uint32_t y = i/w` se računaju unutar `CA_count_neighbors` ali se nikada ne koriste. Ovo je ostatak koda od refaktorisanja.

- `console.cpp:130` i `main.cpp:18` — **Nekorišćene funkcije**: `Console::set_region` i `get_random_unoccupied_tile` su definisane ali se nikada ne pozivaju iz koda igre. `set_region` se koristi u jediničnim testovima, ali `get_random_unoccupied_tile` je zaista mrtav kod.

- `console.cpp:104` i `map.cpp:265` — **Neslaganje imena parametara**: ime parametra u deklaraciji funkcije se razlikuje od imena u definiciji (`g` vs `glyph`, `xy` vs `pos`). Ovo je mali problem koji otežava čitanje koda.

- `console.cpp:130` i `util.cpp:6` — **Parametri prosleđeni po vrednosti**: `set_region` prima `std::vector` po vrednosti, a `log` prima `std::string` po vrednosti, što uzrokuje nepotrebno kopiranje. Ovi parametri treba da se prosleđuju kao `const` referenca.

---

### 2.2 Clang-tidy

Clang-tidy je linter izgrađen na vrhu Clang kompajlerske infrastrukture. Pruža širi opseg provera od Cppcheck-a, uključujući sugestije za modernizaciju i primenu Core Guidelines.

**Greške** — Clang-tidy prijavljuje greške za nedostajuće SFML hedere i za `std::source_location` koji nije pronađen. Ovo nisu stvarne greške: SFML se kompajlira pomoću cmake-a u poseban direktorijum koji nije vidljiv clang-tidy-ju, a `std::source_location` zahteva C++20 za koji clang-tidy nije pozvan s odgovarajućim zastavicama. Projekat se ispravno kompajlira i izvršava.

**Upozorenja (ukupno 104):**

- **bugprone-narrowing-conversions** — `util::distance` u `util.cpp:16` vrši sužavajuću konverziju iz `double` u `float`. Osnovni uzrok je to što `std::pow` i `std::sqrt` vraćaju `double`, ali funkcija vraća `float`. Još važnije, funkcija koristi oduzimanje neoznačenih celih brojeva (`a.x - b.x`) koje će tiho preći graničnu vrednost ako je `a.x < b.x`, proizvodeći veoma veliki broj umesto očekivane negativne razlike. Ovo je stvarni bag: `distance({0,0}, {3,4})` bi vratio veliki pogrešan rezultat, dok `distance({3,4}, {0,0})` vraća tačnih 5.0.

- **bugprone-easily-swappable-parameters** — Nekoliko funkcija ima susedne parametre istog tipa, na primer `set_glyph(uint32_t x, uint32_t y, ...)` i `BSP_recurse_region(...)`. Pozivanje ovih funkcija sa zamenjenim argumentima bi se kompajliralo bez greške ali bi proizvelo neispravno ponašanje.

- **performance-unnecessary-value-param** — Potvrđuje cppcheck nalaz: više funkcija prima `std::string` ili `std::vector` po vrednosti umesto kao `const` referencu.

- **readability-identifier-length** — Jednoslovni nazivi parametara (`x`, `y`, `a`, `b`) se prijavljuju u celom kôdu. Iako su kratki nazivi prihvatljivi za koordinate, alat ih prijavljuje kao ispod preporučene minimalne dužine od 3 karaktera.

- **readability-magic-numbers** — Direktno upisane numeričke vrednosti se pojavljuju u `map.cpp` i `main.cpp` (dimenzije mape, pragovi BSP podele, broj entiteta). Ove vrednosti bi bile jasnije kao imenovane konstante.

- **readability-braces-around-statements** — Nekoliko jednolinijiskih tela `if` naredbi izostavlja vitičaste zagrade, što je čest izvor bagova kada se kôd naknadno modifikuje.

- **modernize-use-trailing-return-type** — Nekoliko slobodnih funkcija koristi tradicionalnu sintaksu `povratniTip imeFunkcije()` umesto C++20 sintakse sa trailing return tipom `auto imeFunkcije() -> povratniTip`. Ovo je stilska preferencija, ne bag.

- **cppcoreguidelines-avoid-c-arrays** i **cppcoreguidelines-pro-bounds-pointer-arithmetic** — Neobrađeni C nizovi i aritmetika pokazivača se pojavljuju u delovima koda gde bi `std::array` i iteratori bili sigurnije alternative.

---

### 2.3 Valgrind

Valgrind je alat za dinamičku analizu koji instrumentuje pokrenuti program radi detekcije grešaka u memoriji i curenja memorije. Izvršna datoteka ONRL-a je pokrenuta pod Valgrind-om sve dok prozor nije ručno zatvoren.

**Rezime curenja memorije:**
```
definitely lost:   184 bytes u 1 bloku
indirectly lost:   1,825 bytes u 2 bloka
possibly lost:     0 bytes u 0 blokova
still reachable:   74,869 bytes u 558 blokova
suppressed:        0 bytes u 0 blokova
```

**Still reachable (74,869 bytes)** — Ova memorija je alocirana tokom izvršavanja programa i bila je još uvek dostupna (tj. pokazivač na nju je još uvek postojao) kada je program završio rad. Najveći doprinos daje konstruktor `gfx::Console` koji alocira SFML prozor i resurse fonta. GUI aplikacije često ostavljaju ovakvu memoriju alociranu pri izlasku iz programa i oslanjaju se na operativni sistem da je oslobodi, pošto OS svakako čisti svu memoriju procesa pri izlasku. Ovo se ne smatra curenjem memorije u tradicionalnom smislu.

**Definitely lost i indirectly lost** — Jedino stvarno curenje memorije (184 bytes, 1 blok) i dva indirektno izgubljena bloka (1,825 bytes) su praćeni kroz Valgrind izveštaj do biblioteke `libdbus-1`, koju SFML koristi interno za međuprocesnu komunikaciju na Linuxu. Ova curenja se dešavaju u kodu biblioteke trećih strana, a ne u izvornom kodu ONRL-a. Sam projekat nema curenja memorije.

---

### 2.4 Jedinični testovi

Jedinični testovi su napisani korišćenjem GoogleTest radnog okvira i nalaze se u `tools/unit-tests/`. Pokrivenost koda je merena pomoću `lcov` i `genhtml`.

**12 testova u 3 grupe, svi prolaze:**

*ConsoleTest* — pokriva klasu `gfx::Console`:
- `CreateConsole` — proverava da konzola može da se konstruiše i da `render()` i `window_display()` završavaju bez bacanja izuzetka
- `SetAndGetGlyph` — proverava da glyph upisan na poziciju može da se pročita sa ispravnim karakterom i bojama
- `SetGlyphOutOfBounds` — proverava da `set_glyph()` baca `std::runtime_error` za koordinate van granica
- `GetGlyphOutOfBounds` — proverava da `get_glyph()` baca `std::runtime_error` za koordinate van granica
- `GetWindow` — proverava da `get_window()` vraća referencu na otvoreni SFML prozor
- `SetRegion` — proverava da `set_region()` ispravno upisuje blok glifova dimenzija 2×2

*UtilTest* — pokriva matematičke funkcije i funkcije za obradu grešaka iz `util.cpp`:
- `DistanceSamePoint` — proverava da je rastojanje od tačke do same sebe 0
- `DistancePythagorean` — proverava izračunavanje rastojanja korišćenjem pravouglog trougla stranica 3-4-5

*SfUtilTest* — pokriva `util::sf::to_string`:
- `ToStringClosed`, `ToStringKeyPressed`, `ToStringMouseMoved` — proveravaju da su poznati SFML tipovi događaja konvertovani u odgovarajući string

**Rezultati pokrivenosti:**

| Fajl | Pokriveni redovi | Pokrivene funkcije |
|---|---|---|
| `console.cpp` | 69/86 (80,2%) | 7/9 (77,8%) |
| `util.cpp` | 13/35 (37,1%) | 4/4 (100%) |

Dve nepokrivene funkcije u `console.cpp` su `get_mouse_tile_xy()` i `poll_event()`, koje zavise od real-time OS unosa (pozicija miša i događaji prozora) i ne mogu biti pokrenute automatizovanim testom bez pokrenute petlje igre. Nepokriveni redovi u `util.cpp` su netestirane `case` grane u switch naredbi `to_string` funkcije.

Napomena: test `DistancePythagorean` testira samo slučaj gde su obe komponente prvog argumenta veće od odgovarajućih komponenti drugog argumenta (`distance({5,6}, {2,2}) == 5.0`). Kao što je identifikovano od strane clang-tidy-ja, pozivanje funkcije u suprotnom smeru (`distance({2,2}, {5,6})`) bi dalo neispravan rezultat zbog prelaska granice neoznačenog celog broja.

---

### 2.5 Lizard

Lizard meri ciklomatsku složenost (CCN) — broj nezavisnih putanja izvršavanja kroz funkciju. CCN od 1 znači funkciju bez grananja. Svaki `if`, `for`, `while` ili `case` u switch naredbi dodaje 1. Podrazumevani prag upozorenja je CCN > 15.

**3 upozorenja od 42 funkcije:**

- **`main` u `main.cpp`** — CCN 31, 107 NLOC. Cela petlja igre se nalazi u jednoj funkciji: čitanje unosa, ažuriranje pozicije igrača, pokretanje AI neprijatelja, renderovanje mape, renderovanje svih entiteta i obrada događaja. Visoka složenost je direktna posledica ovog dizajna. U zrelijoj kôd bazi ove odgovornosti bi bile podeljene na zasebne funkcije ili sisteme.

- **`game::BSP_recurse_region` u `map.cpp`** — CCN 16, 38 NLOC. Ova funkcija implementira rekurzivni algoritam binarnog particionisanja prostora za generisanje mape. Ima mnogo uslovnih grananja za odlučivanje o tome da li da podeli region horizontalno ili vertikalno, koliko veliki treba da budu rezultujući prostori, i kada da zaustavi rekurziju. Složenost ovde je svojstvena algoritmu, a ne problem dizajna.

- **`util::sf::to_string` u `util.cpp`** — CCN 25, 29 NLOC. Ovo je switch naredba sa jednim `case` za svaki od 24 SFML tipa događaja. Svaki case dodaje 1 na CCN, što rezultat čini alarmantnim. U praksi je funkcija trivijalna za čitanje i održavanje. Ovo je poznato ograničenje ciklomatske složenosti kao metrike: kažnjava velike switch naredbe podjednako bez obzira na to koliko su pojedinačni slučajevi jednostavni.

Preostalih 39 funkcija ima CCN ≤ 15, većinom između 1 i 5, što ukazuje da su nealgoritmički delovi kôd baze jednostavni.

---

### 2.6 Hyperfine

Hyperfine je alat za merenje performansi iz komandne linije. Pošto je ONRL interaktivna igra koja sama od sebe nikad ne završava, vreme kompajliranja je izmereno kao smislena alternativna metrika. Merenje primorava na potpuno rekompajliranje pri svakom pokretanju korišćenjem `cmake --build build --clean-first`.

**Rezultati (5 merenja, 1 zagrevanje):**
```
Time (mean ± σ):     15.864 s ±  0.025 s
Range (min … max):   15.712 s … 16.137 s
User: 12.602 s  |  System: 3.262 s
```

Vreme kompajliranja je jako konzistentno — standardna devijacija od 0.025 sekundi kroz 5 merenja ukazuje da na kompajliranje ne utiču pozadinska aktivnost ili varijacije I/O operacija. Ukupno vreme zida iznosi oko 15.9 sekundi.

Korisničko vreme (12.6 s) je manje od vremena zida (15.9 s), što ukazuje da kompajliranje nije u potpunosti paralelizovano. Kada bi cmake koristio sve dostupne procesorske jezgre paralelno, korisničko vreme bi premašivalo vreme zida za otprilike broj jezgara. Preostala razlika se delom objašnjava sistemskim vremenom (3.3 s) potrošenim na I/O operacije i linkovanje, koji su po prirodi sekvencijalni.

Za projekat ove veličine (oko 700 NLOC u 6 jedinica prevođenja), vreme kompajliranja od 15.9 sekundi je relativno dugo. Glavni doprinos tome je SFML zavisnost koji cmake preuzima i kompajlira iz izvornog koda kao deo procesa izgradnje, umesto korišćenja unapred instalirane sistemske biblioteke.

---

## 3. Zaključci

Alati za statičku analizu (Cppcheck i Clang-tidy) se slažu oko konzistentnog skupa problema sa kvalitetom koda:

- **Poređenja neoznačenog tipa sa nulom** se pojavljuju i u `map.cpp` i u `unit.cpp`. Provere `x >= 0` i `x < 0` na promenljivima tipa `uint32_t` su uvek tačne, odnosno uvek netačne, što znači da granični uslovi koje su trebale da čuvaju zapravo nikada nisu provereni. Ovo je latentni bag: pločice ili entiteti na poziciji (0, 0) mogu zaobići provere granica za koje je programer pretpostavljao da postoje.

- **Parametri prosleđeni po vrednosti** umesto kao `const` referenca u `log()` i `set_region()` uzrokuju nepotrebno kopiranje `std::string` i `std::vector` pri svakom pozivu. Za roguelike koji poziva `log()` često tokom renderovanja, ovo je manji ali nepotreban performansni trošak.

- **`util::distance` sadrži bag prelaska granice neoznačenog celog broja.** Funkcija oduzima neoznačene cele brojeve bez provere koji je veći, što znači da je rezultat ispravan samo kada je prvi argument komponentno veći ili jednak drugom. Ovo je potvrđeno jediničnim testovima: test `DistancePythagorean` je namerno napisan da izbegne okidanje ovog baga.

- **Funkcija `main`** ima ciklomatsku složenost od 31, što je najjasniji strukturni problem u kodu. Ona obrađuje unos, AI, fiziku i renderovanje u jednoj funkciji. Ovo čini petlju igre teškom za proširivanje i nemogućom za testiranje u izolaciji.

- **Upravljanje memorijom je čisto** na nivou projekta. Valgrind nije pronašao curenja u sopstvenom kodu ONRL-a. Jedina curenja se prate do `libdbus-1`, sistemske biblioteke koju SFML interno koristi na Linuxu, a nad kojom projekat nema kontrolu.

- **Vreme kompajliranja** je dominantno određeno SFML zavisnošću koja se kompajlira iz izvornog koda. Sam izvorni kod projekta je mali i kompajlirao bi se za manje od sekunde u izolaciji.

Najznačajniji nalazi su bagovi sa poređenjem neoznačenih tipova u `map.cpp` i `unit.cpp`, bag prelaska granice u `util::distance`, i monolitna funkcija `main`. Nijedan od ovih bagova ne uzrokuje vidljivo neispravno ponašanje u normalnim uslovima igranja, ali predstavljaju rizike po pouzdanost koji bi morali biti rešeni pre nego što bi projekat mogao biti smatran spremnim za produkciju.
