package family;

import java.util.Collection;
import java.util.HashSet;

public class Household extends DomainObject
{
    private Address address;
    
    private Collection<Person> members;

    public Household()
    {
        members = new HashSet<Person>();
    }

    public Address getAddress()
    {
        return address;
    }

    public void setAddress(Address address)
    {
        this.address = address;
    }

    public Collection<Person> getMembers()
    {
        return members;
    }

    public void setMembers(Collection<Person> members)
    {
        this.members = members;
    }
}
