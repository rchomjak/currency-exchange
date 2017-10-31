use v6;

use Bank;

unit module NBP;

class  NBP::NBP does Bank::currency-value {

    use JSON::Tiny;
    use HTTP::Tinyish;

    has %.valutes;
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
        $.url = $.url ~ "$.table/$.currency/$.date?format=json";
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
