use v6;
sub MAIN(:$source, :$target, :$count, :$debug) {
    say "source: $source" if $source.defined;
    say "target: $target" if $count.defined;
    say "count:  $count" if $count.defined;
    say "debug:  $debug" if $debug.defined;
}

sub USAGE(){
print Q:c:to/EOH/;
Usage: {$*PROGRAM-NAME} [number]

Prints the answer or 'dunno'.
EOH
}


use HTTP::Tinyish;


role currency-value {

    method new {}
    method download_data {}
    method check_data {}
    method return_data {}
    method set_url {}
}


class  NBP-REFERENCE does currency-value {

    use JSON::Tiny;

    has %.valutes is rw;
    has %.res;
    has Str $.currency;
    has Str $.table;
    has Str $.url is rw = qqww{http://api.nbp.pl/api/exchangerates/rates/} ;
    has Str $.date;
    has Bool $.dwn_state is rw = False;
    has Int $.http_timeout;

    method new(Str $currency_?, Int $http_timeout_=5, Str $table_="a", Str $date_=Date.today.gist.Str, Str :$currency=$currency_, Str :$table=$table_, Str :$date=$date_, Int :$http_timeout=$http_timeout_) {
        self.bless(:$currency, :$table, :$date, :$http_timeout);
    }
    method TWEAK() {

        $.url = $.url ~ "$.table/$.currency?format=json";
        #%.valutes = Nil;
    }

    method set_url (Str $new_url) {
        $.url = $new_url;
    }

    method download_data{

        my $http = HTTP::Tinyish.new(agent => 'Mozilla/5.0', timeout=>$.http_timeout);
        %.res = $http.get($.url);

        if %.res<status>.Int == 200 {
            $.dwn_state = True;
        }

        self
    }

    method make_data {

        if  $.dwn_state == False {
            return self
        }

        my %res_content = from-json %.res<content>;

        %.valutes{"code"} = %res_content<code>;
        %.valutes{"full_name"} = %res_content<currency>;
        %.valutes{"date"} = %(%res_content<rates>[0])<effectiveDate>;
        %.valutes{"price"} = %(%res_content<rates>[0])<mid>;

        self;
    }

}


class  NBP does currency-value {

    use JSON::Tiny;

    has %.valutes is rw;
    has %.res;
    has Str $.currency;
    has Str $.table;
    has Str $.url is rw = qqww{http://api.nbp.pl/api/exchangerates/rates/} ;
    has Str $.date;
    has Bool $.dwn_state is rw = False;
    has Int $.http_timeout;

    method new(Str $currency_?, Str $table_="c", Int $http_timeout_=5, Str $date_=Date.today.gist.Str, Int :$http_timeout=$http_timeout_, Str :$currency = $currency_, Str :$table=$table_, Str :$date=$date_) {
        self.bless(:$currency, :$table, :$date, :$http_timeout);
    }
    method TWEAK() {
        $.url = $.url ~ "$.table/$.currency?format=json";
        #%.valutes = Nil;
    }

    method set_url (Str $new_url) {
        $.url = $new_url;
    }

    method download_data{

        my $http = HTTP::Tinyish.new(agent => 'Mozilla/5.0', timeout=>$.http_timeout);
        %.res = $http.get($.url);

        if %.res<status>.Int == 200 {
            $.dwn_state = True;
        }

        self
    }

    method make_data {

        if  $.dwn_state == False {
            return self
        }


    my %res_content = from-json %.res<content>;

    %.valutes{"code"} = %res_content<code>;
    %.valutes{"full_name"} = %res_content<currency>;
    %.valutes{"date"} = %(%res_content<rates>[0])<effectiveDate>;

    %.valutes{"ask"} = %(%res_content<rates>[0])<ask>;
    %.valutes{"bid"} = %(%res_content<rates>[0])<bid>;

    self;

    }

}


class  MBANK does currency-value  {

    use IO::String;
    use CSV::Parser;

    has %.valutes is rw;
    has %.res;
    has Str $.currency;
    has Str $.table;
    has Str $.url is rw = qqww{https://www.mbank.pl/ajax/currency/getCSV/?id=1};
    has Str $.date;
    has Bool $.dwn_state is rw = False;
    has Int $.http_timeout;

    method new(Str $currency_?, Int $http_timeout_=5,  Str $date_=Date.today.gist.Str, Int :$http_timeout=$http_timeout_, Str :$currency = $currency_, Str :$date=$date_) {
        self.bless(:$currency, :$date, :$http_timeout);
    }
    method TWEAK() {
        $.url = $.url ~ "\$date=$.date&lang=en";
        #%.valutes = Nil;
    }

    method set_url (Str $new_url) {
        $.url = $new_url;
    }

    method download_data{

        my $http = HTTP::Tinyish.new(agent => 'Mozilla/5.0', timeout=>$.http_timeout);
        %.res = $http.get($.url);

        if %.res<status>.Int == 200 {
            $.dwn_state = True;
        }

        self
    }

    method make_data {

        if  $.dwn_state == False {
            return self
        }

        my $Strio_buffer = IO::String.new(buffer=>$.res<content>);

        #Seek to third line => Where data lines start.
        $_ = $Strio_buffer.get();
        my $line_date_ = $Strio_buffer.get();

        if $line_date_ ~~ /(\d\d\d\d\-\d\d\-\d\d)/ {
            %.valutes{"date"} = $0.Str;
        }


        my $csv_parser = CSV::Parser.new(file_handle=>$Strio_buffer,
                                         contains_header_row => True,
                                         field_separator=>';');
        my %csv_data;


        while %csv_data = %($csv_parser.get_line()) {

            if %csv_data<Currency> eq $.currency {
                %.valutes{"code"} = $.currency;
                %.valutes{"full_name"} = %csv_data{"Name"};
                %.valutes{"ask"} = %csv_data{"Sell"}.Rat/%csv_data{"Reference number"}.Rat;
                %.valutes{"bid"} = %csv_data{"Buy"}.Rat/%csv_data{"Reference number"}.Rat;
                last;
            }

        }



        self;
    }

}


class  PEKAO does currency-value {
    #Currency exchange works only for Date.today, I do not know how to find proper table for another day :-X
    use XML;
    use IO::String;

    has %.valutes is rw;
    has %.res;
    has Str $.currency;
    has Str $.table;
    has Int $.http_timeout=5;
    has Str $.url is rw = qqww{https://www.pekao.com.pl/exchange_static?type=pekao&format=XML};
    has Str $.date;
    has Bool $.dwn_state is rw = False;


    method new(Str $currency_?, Int $http_timeout_=10, Str $date_=Date.today.gist.Str, Int :$http_timeout=$http_timeout_, Str :$currency = $currency_, Str :$date=$date_) {

        self.bless(:$currency, :$date, :$http_timeout);
    }
    method TWEAK() {
        #%.valutes = Nil;
    }

    method set_url (Str $new_url) {
        $.url = $new_url;
    }

    method download_data{

    #    say $.http_timeout;
        my $http = HTTP::Tinyish.new(agent => 'Mozilla/5.0', timeout=>$.http_timeout);
        %.res = $http.get($.url);

        if %.res<status>.Int == 200 {
            $.dwn_state = True;
        }

        self
    }

    method make_data {

        if  $.dwn_state == False {
            return self
        }

        my $xml_parsed = XML::Document.new(%.res{"content"});
        my @valute_nodes;
        my $searched_element = Nil;
        my $record_date;




        $xml_parsed = XML::Document.new(%.res{"content"});

        my $form_date = $xml_parsed.getElementsByTagName("data_publikacji");
        if $form_date[0].contents()[0] ~~ /((\d\d?)\.(\d\d?)\.(\d\d\d\d))/ {
            my %m_pair =  $0.pairs();

            $record_date = %m_pair<2>.Str ~ "-" ~ %m_pair<1>.Str ~ "-" ~ %m_pair<0>.Str;

        }

        for $xml_parsed.getElementsByTagName("pozycja") -> $valute_info {

          @valute_nodes = $valute_info.elements(:TAG<iso>);
          for @valute_nodes -> $valute_node {
            if $valute_node.contents()[0] eq $.currency {
              $searched_element = $valute_info;
              last;
            }
          }
        }

        if $searched_element.defined {

          %.valutes{"code"} = $searched_element.getElementsByTagName("iso")[0].contents[0].Str;
          %.valutes{"full_name"} = $searched_element.getElementsByTagName("kraj")[0].contents[0].Str;
          %.valutes{"date"} = $record_date if $record_date.defined;
          %.valutes{"ask"} = $searched_element.getElementsByTagName("sprzedaz")[0].contents[0];
          %.valutes{"bid"} =  $searched_element.getElementsByTagName("kupno")[0].contents[0];

          say %.valutes;
        }


        self;
    }

}
MAIN();

my $NBP-ref = NBP-REFERENCE.new(currency=>"CHF");
my $nbp = NBP.new(currency=>"CHF");
my $mbank = MBANK.new(currency=>"CHF");


my $pekao1 = PEKAO.new(currency=>"CHF");
my $pekao2 = PEKAO.new(currency=>"USD");
my $pekao3 = PEKAO.new(currency=>"CHF");

#say $NBP-ref.download_data.make_data.valutes;
#say $nbp.download_data.make_data.valutes;
#say $mbank.download_data.make_data.valutes;
#say $pekao.download_data.make_data.valutes;


my @pekaos = ($pekao1, $pekao2, $pekao3);

my @objs = (NBP-REFERENCE.new(currency=>"CHF"), NBP.new(currency=>"CHF"), MBANK.new(currency=>"CHF"), PEKAO.new(currency=>"CHF")); #,$pekao);
my @results1 =  @objs.race.map({start $_.download_data.make_data.eager});
await @results1;

#dd @results1[0];
say now - INIT now;

dd @objs[0];

#await @results1;
#await @results2;

#say @results2;


#$a.download_data;

#$a.make_data;
#say $a


#$a.download_data;
#$a.make_data;
#my $b = PEKAO.new(currency=>"chf");
#$b.download_data;
