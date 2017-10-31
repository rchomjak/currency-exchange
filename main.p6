#!/usr/bin/env perl6
use v6;

use HTTP::Tinyish;

use lib 'lib';

require Bank;
require NBPref;
require NBP;
require MBANK;
require PEKAO;

use Bank;
use NBPref;
use NBP;
use MBANK;
use PEKAO;

my %*SUB-MAIN-OPTS =
  :named-anywhere,    # allow named variables at any location
;

multi sub MAIN(Str :$buy-sell="all", Int :$http-timeout=10, Str :$date=Date.today.gist.Str, Str :$currency! is rw) {

    my @objs_parallel;
    my @parallel_data;
    my $ref_bank;

    if $buy-sell !~~ m/"buy"|"sell"|"all"/ {
      USAGE();
      exit;
    }
    if $date !~~ /((\d\d\d\d)\-(\d\d)\-(\d\d))/  {
      USAGE();
      exit;
    }
    $currency = $currency.uc;



    if Date.new($date).gist.Str eq Date.today.gist.Str {
        @objs_parallel = (NBPref::NBPref.new(currency=>$currency, http_timeout=>$http-timeout, date=>$date),
                            NBP::NBP.new(currency=>$currency, http_timeout=>$http-timeout, date=>$date),
                            MBANK::MBANK.new(currency=>$currency, http_timeout=>$http-timeout, date=>$date),
                            PEKAO::PEKAO.new(currency=>$currency, http_timeout=>$http-timeout, date=>$date));
    } else {
        say $date;
        @objs_parallel = (NBPref::NBPref.new(currency=>$currency, http_timeout=>$http-timeout, date=>$date),
                            NBP::NBP.new(currency=>$currency, http_timeout=>$http-timeout, date=>$date),
                            MBANK::MBANK.new(currency=>$currency, http_timeout=>$http-timeout, date=>$date));

    }


    @parallel_data =  @objs_parallel.hyper.map({start $_.download_data.make_data.eager});
    await @parallel_data;



    my @sell =  @objs_parallel.grep({ .WHAT.gist !~~ /"NBPref"/}).sort({$_.valutes{'bid'}});

    say @sell.map({$_.valutes});

    my @buy = @objs_parallel.grep({ .WHAT.gist !~~ /"NBPref"/}).sort({$_.valutes{'ask'}});
    say "------";
    say @buy.map({$_.valutes});

}






sub USAGE(){
print Q:c:to/EOH/;
Usage: {$*PROGRAM-NAME} [number]
"ISO 4217"
Prints the answer or 'dunno'.
EOH
}
