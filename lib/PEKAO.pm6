
use Bank;
unit module PEKAO;


class  PEKAO::PEKAO does Bank::currency-value {
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
