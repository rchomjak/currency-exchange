unit module Bank;

role Bank::currency-value is export {

    method new {}
    method download_data {}
    method check_data {}
    method return_data {}
    method set_url {}
}
