package family;

import java.util.Date;

public class Person extends DomainObject
{
    private String name;
    
    private Date birthDate;

    private Household household;

    public String getName()
    {
        return name;
    }

    public void setName(String value)
    {
        this.name = value;
    }
    
    public Date getBirthDate()
    {
        return birthDate;
    }
    
    public void setBirthDate(Date date)
    {
        this.birthDate = date;
    }

    public Household getHousehold()
    {
        return household;
    }

    public void setHousehold(Household household)
    {
        this.household = household;
    }
}
