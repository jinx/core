package domain;

public class Dependent extends DomainObject
{
    /**
     * A string property.
     */
    private String name;

    public Dependent()
    {
    }

    /**
     * @return the name
     */
    public String getName()
    {
        return name;
    }

    /**
     * @param name the name to set
     */
    public void setName(String name)
    {
        this.name = name;
    }
}
