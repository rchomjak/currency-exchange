use v6;

use Bank;

unit module NBPref;

class  NBPref::NBPref does Bank::currency-value  {

    use JSON::Tiny;
    use HTTP::Tinyish;

    has %.valutes is rw;
    has %.res;
    has Str $.currency;
    has Str $.table;
    has Str $.url is rw = qqww{http://api.nbp.pl/api/exchangerates/rates/} ;
    has Str $.date;
    has Bool $.dwn_state is rw = False;
    has Bool $.down_correct_data is rw = False;
    has Int $.http_timeout;

    method new(Str $currency_?, Int $http_timeout_=5, Str $table_="a", Str $date_=Date.today.gist.Str, Str :$currency=$currency_, Str :$table=$table_, Str :$date=$date_, Int :$http_timeout=$http_timeout_) {

        my $dwn_state = False;
        my $down_correct_data = False;
        self.bless(:$currency, :$table, :$date, :$http_timeout, :$dwn_state, :$down_correct_data);
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

        if %.res<success> {
          $.dwn_state = True;
        }


        if %.res<status>.Int == 200 {
            $.down_correct_data = True;
        }

        self
    }

    method make_data {

        if  $.dwn_state == False or $.down_correct_data == False {
            return self
        }

        my %res_content = from-json %.res<content>;

        %.valutes{"code"} = %res_content<code>;
        %.valutes{"full_name"} = %res_content<currency>;
        %.valutes{"date"} = %(%res_content<rates>[0])<effectiveDate>;
        %.valutes{"price"} = %(%res_content<rates>[0])<mid>;

        self;
    }

class  NBPref::NBPrefCurrList does Bank::currency-value {

        use JSON::Tiny;
        use HTTP::Tinyish;

        has %.valutes is rw;
        has %.res;
        has Str $.table;
        has Str $.url is rw = qqww{http://api.nbp.pl/api/exchangerates/tables/} ;
        has Bool $.dwn_state is rw = False;
        has Bool $.down_correct_data is rw = False;
        has Int $.http_timeout;
        has $.currency_code_name is rw;

        method new(Int $http_timeout_=5, Str $table_="a",  Str :$table=$table_,  Int :$http_timeout=$http_timeout_) {
            self.bless(:$table, :$http_timeout);
        }
        method TWEAK() {

            $.url = $.url ~ "$.table?format=json";
        }

        method set_url (Str $new_url) {
            $.url = $new_url;
        }

        method download_data{

            my $http = HTTP::Tinyish.new(agent => 'Mozilla/5.0', timeout=>$.http_timeout);
            %.res = $http.get($.url);

            if %.res<success> {
              $.dwn_state = True;
            }


            if %.res<status>.Int == 200 {
                $.down_correct_data = True;
            }
            self
        }

        method make_data {

            if  $.dwn_state == False or $.down_correct_data == False {
                return self
            }

            my @res_content = from-json %.res<content>;
            $.currency_code_name = @res_content[0][0]<rates>;
            #@.currency_code_name = %res_content('rates');
            self;
        }

    }
}
