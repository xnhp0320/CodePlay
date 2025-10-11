module tbm;
import tbmlib::bitmap;
import std::io;

fn int main(String[] args)
{
    tbmlib::bitmap::print_inl_check_map{7}(io::stdout());
	return 0;
}
