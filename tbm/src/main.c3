module tbm;
import tbmlib;
import std::io;

fn int main(String[] args)
{
    tbmlib::print_inl_check_map{7, uint, uint}(io::stdout());
	return 0;
}
