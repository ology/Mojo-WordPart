# Mojo::WordPart

A modern-Perl Mojolicious app to analyze science-words with roots and affixes.

```shell
git clone https://github.com/ology/Mojo-WordPart.git
cd Mojo-WordPart

cpanm --installdeps .

sqlite3 word_partition.db < word_part.sql

morbo script/word_partition
```
