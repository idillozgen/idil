# Proje Kuralları & Yönergeleri

## Dosya İşlemleri ve Arama Kuralı (Kritik)
- Dosyaları okumak, listelemek veya kod içinde arama yapmak için **ASLA** `run_command` üzerinden terminal komutlarını (`cat`, `grep`, `ls`, `dir`, `Select-String`, `Get-ChildItem` vb.) kullanma.
- Bu işlemler için her zaman mecburi olarak **`view_file`** ve ilgili yerleşik araçları (`write_to_file`, `replace_file_content`) kullan.
