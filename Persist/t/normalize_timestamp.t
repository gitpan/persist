# vim: set ft=perl :

use Test::More tests => 8;
use Persist ':constants';

is(Persist->normalize_timestamp(
		'120030617125344-0600'
   ), '120030617185344+0000', 'normalize_timestamp negative');

is(Persist->normalize_timestamp(
		'120030617125344+0600'
   ), '120030617065344+0000', 'normalize_timestamp positive');

is(Persist->normalize_timestamp(
		'120030617125344-0630'
   ), '120030617192344+0000', 'normalize_timestamp negative with hours roll-over');

is(Persist->normalize_timestamp(
		'120030617122344+0630'
   ), '120030617055344+0000', 'normalize_timestamp positive with hours roll-over');

is(Persist->normalize_timestamp(
		'120030617205344-1200'
   ), '120030618085344+0000', 'normalize_timestamp negative with days roll-over');

is(Persist->normalize_timestamp(
		'120030617075344+1200'
   ), '120030616195344+0000', 'normalize_timestamp positive with days roll-over');

is(Persist->normalize_timestamp(
		'120031131204530-0800'
   ), '120040001044530+0000', 'normalize_timestamp negative with complete roll-over');

is(Persist->normalize_timestamp(
		'120030001044530+0800'
   ), '120021131204530+0000', 'normalize_timestamp positive with complete roll-over');
