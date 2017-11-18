#!/usr/bin/env perl6
use v6.c;

BEGIN {try {
require XML;
require IO::String;
require HTTP::Tinyish;
require CSV::Parser;
require JSON::Tiny;
    CATCH {

        when X::CompUnit::UnsatisfiedDependency {
         say "WARNING !!!: Problem with modules.";
         say "Dependencies: XML, IO::String, HTTP::Tinyish, CSV::Parser, JSON::Tiny";
         say "";
         print Q:c:to/EOH/;
         Downloads and sorts currency rates for specified operation based on currency.
         Program shows mid. currency rate (Zloty) based on National Bank of Poland as reference.

         Every bank output record is in ZL (PLN) => Zloty currency.

         List of banks which sell/buys currency:
         NBP (National Bank of Poland) - NBP also sells/buys currency , PEKAO, MBANK

         Usage:
             {$*PROGRAM-NAME} --currency=<Str> [--buy-sell=<Str>] [--http-timeout=<Int>] [--date=<Str>]
             {$*PROGRAM-NAME} --currency-list

         Where 'currency'
             is ISO 4217 symbol, not every currency bank sells/buys.
         Where 'buy-sell'
             what you want to see from banks, choice buy, sell, all.
         Where 'http-timeout'
             defines HTTP/s timeout for requests. (GLOBAL) default 15.
         Where 'date'
             defines date in format YYYY-MM-DD from which date you want record.
             NOTE: Bank PEKAO works only for 'date' = today

         Examples:
             Returns everything (sell/buy) in currency CZK in date today.
             {$*PROGRAM-NAME} --currency=CZK

             Returns buy in currency CZK in date 2017-10-25.
             {$*PROGRAM-NAME} --buy-sell='buy' --currency=CZK --date="2017-10-25"

             Returns currency list
             {$*PROGRAM-NAME} --currency-list

         NOTE:
             Important:
                 If you have specified date as weekend or day when markets were close.
                 You will may get same error response as problem with internet connection.

             Some banks do not handle currency which can be listed with parameter --currency-list

         DEPENDENCIES:
             XML, HTTP::Tinyish, CSV::Parser, JSON::Tiny, IO::String

         EOH

}
        default {.resume}
    }
}}




use lib $*PROGRAM.sibling: 'lib';;
use XML;
use IO::String;
use HTTP::Tinyish;
use CSV::Parser;
use JSON::Tiny;

use Bank;
use NBPref;
use NBP;
use MBANK;
use PEKAO;


my %*SUB-MAIN-OPTS =
  :named-anywhere,    # allow named variables at any location
;

multi sub MAIN(Str :$buy-sell="all", Int :$http-timeout=15, Str :$date=Date.today.gist.Str, Str :$currency! is rw) {

    my @objs_parallel;
    my @parallel_data;
    my $ref_bank;

    if $buy-sell !~~ m/"buy"|"sell"|"all"/ {
      USAGE();
      exit;
    }

    $currency = $currency.uc;

    try {
      Date.new($date);
      CATCH {
        default {
          say "Invalid Date string " ~ $date ~ " use YYYY-MM-DD format";
          exit
        }
      }
    }

    if Date.new($date) > Date.today {
        say "You are trying reach a future, your date is invalid." ;
        exit;

    }

    if Date.new($date).day-of-week == 7 || Date.new($date).day-of-week == 6 {
        say "Date " ~ $date ~ " is weekend, markets are close.";
        exit;

    }

    if Date.new($date).gist.Str eq Date.today.gist.Str {
        @objs_parallel = (NBPref::NBPref.new(currency=>$currency, http_timeout=>$http-timeout, date=>$date),
                            NBP::NBP.new(currency=>$currency, http_timeout=>$http-timeout, date=>$date),
                            MBANK::MBANK.new(currency=>$currency, http_timeout=>$http-timeout, date=>$date),
                            PEKAO::PEKAO.new(currency=>$currency, http_timeout=>$http-timeout, date=>$date));
    } else {
        @objs_parallel = (NBPref::NBPref.new(currency=>$currency, http_timeout=>$http-timeout, date=>$date),
                            NBP::NBP.new(currency=>$currency, http_timeout=>$http-timeout, date=>$date),
                            MBANK::MBANK.new(currency=>$currency, http_timeout=>$http-timeout, date=>$date));

    }


    @parallel_data =  @objs_parallel.hyper.map({start $_.download_data.make_data.eager});
    await @parallel_data;

    my @cannot_download = @objs_parallel.grep({$_.dwn_state == False});

    if @cannot_download.elems {
        say "Cannot download data for following banks:";

        for @cannot_download -> $elem {
            say $elem.WHAT.gist.Str ~" url: " ~ $elem.url;
        }

    }

    my @ref_objs = @objs_parallel.grep({ $_.dwn_state && $_.valutes.defined && $_.valutes.elems && $_.WHAT.gist.Str ~~ /"NBPref"/});


    my $nbp_text = sub (@ref) {
        if  ! @ref.elems {
            say "For date $date, the reference Central Bank (National Bank of Poland) does not have record.";
            say "exiting...";
            exit;
        } else {
            my $ref = @ref[0];
            say "-.-."x(20);
            say "Reference bank,the National Bank of Poland, for $date, in currency $currency";
            say "-.-."x(20);

            say "ISO code: ", $ref.valutes{"code"};
            say "Full name in record: ", $ref.valutes{"full_name"};
            say "Date in record: ", $ref.valutes{"date"};
            say "Mid. price: ", $ref.valutes{"price"};
            say "-.-."x(20);
        }
    }

    my $sell_func = {

        my @sell_objs =  @objs_parallel.grep({ $_.dwn_state && $_.valutes.defined && $_.valutes.elems && $_.WHAT.gist.Str !~~ /"NBPref"/}).sort({-1*$_.valutes{'bid'}});
        say "-.-."x(20);
        say "Sorted price of banks for sell";
        say "-.-."x(20);
        say "Bank name, ISO code, date, sell price (bid):";
        for @sell_objs -> $bank {
            if $bank.valutes.defined {
                say $bank.WHAT.gist.Str, ", ", $bank.valutes{'code'}, ", ",  $bank.valutes{'date'}, ", ", $bank.valutes{'bid'};
            }
        }
        say "";
    }



    my $buy_func = {

        my @sell_objs =  @objs_parallel.grep({$_.dwn_state && $_.valutes.defined && $_.valutes.elems && $_.WHAT.gist.Str !~~ /"NBPref"/}).sort({$_.valutes{'ask'}});
        say "-.-."x(20);
        say "Sorted price of banks for buy";
        say "-.-."x(20);
        say "Bank name, ISO code, date, buy price (ask):";
        for @sell_objs -> $bank {
            if $bank.valutes.defined {
                say $bank.WHAT.gist.Str, ", ", $bank.valutes{'code'}, ", ",  $bank.valutes{'date'}, ", ", $bank.valutes{'ask'};
            }
        }
        say "";
    }



    $nbp_text(@ref_objs);
    if $buy-sell eq 'all' || $buy-sell eq 'sell' {
        $sell_func();
    }
    if $buy-sell eq 'all' || $buy-sell eq 'buy' {
        $buy_func();
    }


}


multi sub MAIN(Bool :$currency-list!) {
    my $a = NBPref::NBPrefCurrList.new();
    $a.download_data.make_data;


    if ($a.dwn_state == False) {
        say "Cannot dowload currency-list from NBP.";
        exit;
    }


    say "ISO Code, " ~ " " ~  "Name of currency";
    say "-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.";


    #dd $a.currency_code_name;
    for $a.currency_code_name[0..*] -> %currency_data {
        #say %currency_data<code>, $currency_data<currency>;
        say %currency_data<code> ~ ", " ~ %currency_data<currency>;
    }
}



sub USAGE(){
print Q:c:to/EOH/;

Downloads and sorts currency rates for specified operation based on currency.
Program shows mid. currency rate (Zloty) based on National Bank of Poland as reference.

Every bank output record is in ZL (PLN) => Zloty currency.

List of banks which sell/buys currency:
NBP (National Bank of Poland) - NBP also sells/buys currency , PEKAO, MBANK

Usage:
    {$*PROGRAM-NAME} --currency=<Str> [--buy-sell=<Str>] [--http-timeout=<Int>] [--date=<Str>]
    {$*PROGRAM-NAME} --currency-list

Where 'currency'
    is ISO 4217 symbol, not every currency bank sells/buys.
Where 'buy-sell'
    what you want to see from banks, choice buy, sell, all.
Where 'http-timeout'
    defines HTTP/s timeout for requests. (GLOBAL) default 15.
Where 'date'
    defines date in format YYYY-MM-DD from which date you want record.
    NOTE: Bank PEKAO works only for 'date' = today

Examples:
    Returns everything (sell/buy) in currency CZK in date today.
    {$*PROGRAM-NAME} --currency=CZK

    Returns buy in currency CZK in date 2017-10-25.
    {$*PROGRAM-NAME} --buy-sell='buy' --currency=CZK --date="2017-10-25"

    Returns currency list
    {$*PROGRAM-NAME} --currency-list

NOTE:
    Important:
        If you have specified date as weekend or day when markets were close.
        You will may get same error response as problem with internet connection.

    Some banks do not handle currency which can be listed with parameter --currency-list

DEPENDENCIES:
    XML, HTTP::Tinyish, CSV::Parser, JSON::Tiny, IO::String

EOH
}
