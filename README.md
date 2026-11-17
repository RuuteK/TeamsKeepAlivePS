# TeamsKeepAlivePS — poprawiona wersja

Wymagania: Windows 10/11, Windows PowerShell 5.1, interaktywna sesja pulpitu.

## Uruchomienie
1. Zamknij stara wersje przez ikonke w zasobniku.
2. Wypakuj CALA paczke ZIP do osobnego folderu.
3. Kliknij dwa razy Uruchom_ukryte.vbs — aplikacja uruchomi sie w tle, z ikonka obok zegara. Wymaga wlaczonego VBScript / Windows Script Host.
4. Jesli VBS jest niedostepny lub aplikacja nie startuje, uzyj Uruchom.cmd. Okno konsoli pozostaje widoczne, aby pokazac bledy.
5. Zamknij aplikacje przez ikonke w zasobniku -> Zamknij.

Skrypty musza byc dopuszczone przez ustawienia Windows/organizacji. Uruchamianie nie omija zasad wykonywania skryptow. Jesli system blokuje plik, przekaz komunikat administratorowi.

## Dzialanie i ograniczenia
Aplikacja powstrzymuje automatyczne usypianie z bezczynnosci. Po dwoch minutach bezczynnosci wysyla drobny ruch myszy co piec sekund. Nie zapobiega zamknieciu Windows, restartom, recznemu uspieniu ani blokadzie ekranu. Nie zmienia ustawien zasilania na stale. Po zamknieciu zwalnia zadanie podtrzymywania zasilania.

Nie ma gwarancji zielonego statusu w Teams: zalezy on od wersji Teams, blokady sesji, ustawien konta i zasad organizacji. Skrypt nie odblokowuje ekranu i nie zmienia zasad organizacji. Windows nie pozwala niezawodnie odroznic wszystkich zdarzen fizycznych od syntetycznych za pomoca samego GetLastInputInfo; dotychczasowy mechanizm obserwacji zachowano.

## Naprawione problemy
- Prawidlowa struktura INPUT dla Windows 32/64-bit.
- Obliczanie bezczynnosci z uwzglednieniem przepelnienia licznika systemowego.
- Kontrola wynikow wywolan Windows; zamiast cichego bledu aplikacja zatrzymuje podtrzymywanie i pokazuje powiadomienie.
- Sprzatanie zasobow i zwalnianie blokady usypiania przy zakonczeniu.
- Blokada wielu kopii w obrebie sesji zamiast globalnej blokady.
- Uruchamianie w STA i alternatywa CMD dla wygaszanego VBScript.

## Diagnostyka
Log bledow: %LOCALAPPDATA%\TeamsKeepAlive\error.log
Jesli aplikacja nadal nie dziala, przeslij tresc komunikatu lub logu oraz wersje Windows i Teams. Log powstaje dopiero po bledzie obslugiwanym przez skrypt; blokada przed startem moze byc widoczna tylko w konsoli.

Weryfikacja w tej paczce: przeglad kodu, sprawdzenie ukladu struktur INPUT dla x86/x64 i arytmetyki przepelnienia. Nie przeprowadzono uruchomienia na Windows ani testu z Teams.

## Pobieranie z GitHuba
Kliknij Code -> Download ZIP, wypakuj calosc i uruchom Uruchom_ukryte.vbs. Nie uruchamiaj plikow bezposrednio z archiwum.
